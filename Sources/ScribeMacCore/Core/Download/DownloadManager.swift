import Foundation
import os

/// Thread-safe coordinator for downloading, validating, and organizing documents.
public actor DownloadManager {
    public nonisolated let organizer: FileOrganizer
    public nonisolated let validator: DownloadValidator

    private var activeDownloadTasks: [UUID: URLSessionDownloadTask] = [:]
    private var cancelledJobIds: Set<UUID> = []

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 600.0
        return URLSession(configuration: config, delegate: nil, delegateQueue: nil)
    }()

    public init(organizer: FileOrganizer = FileOrganizer(), validator: DownloadValidator = DownloadValidator()) {
        self.organizer = organizer
        self.validator = validator
    }

    /// Cancels an in-flight download job.
    public func cancel(jobId: UUID) {
        cancelledJobIds.insert(jobId)
        if let task = activeDownloadTasks[jobId] {
            AppLogger.download.info("Cancelando descarga para el trabajo \(jobId)")
            task.cancel()
            activeDownloadTasks.removeValue(forKey: jobId)
        }
    }

    /// Executes the full download and validation pipeline for a given job.
    /// Returns the updated DocumentJob reflecting final status, local path, sha256, and metadata.
    public func execute(
        job: DocumentJob,
        downloadURL: URL,
        suggestedFilename: String? = nil,
        onProgress: (@Sendable (Double, Int64, Int64) -> Void)? = nil
    ) async throws -> DocumentJob {
        var currentJob = job
        currentJob.downloadStatus = .downloading
        currentJob.sourceURL = downloadURL

        try organizer.createDirectoriesIfNeeded()

        let tempIncomingURL = organizer.incomingDirectory.appendingPathComponent("dl-\(job.id.uuidString).tmp")

        // Clean up any stale temp file
        try? FileManager.default.removeItem(at: tempIncomingURL)

        defer {
            try? FileManager.default.removeItem(at: tempIncomingURL)
            activeDownloadTasks.removeValue(forKey: job.id)
            cancelledJobIds.remove(job.id)
        }

        do {
            // Handle file:// URLs (such as local fixtures)
            if downloadURL.isFileURL {
                AppLogger.download.info("Procesando recurso local fixture: \(downloadURL.path)")
                try FileManager.default.copyItem(at: downloadURL, to: tempIncomingURL)
                let attr = try FileManager.default.attributesOfItem(atPath: tempIncomingURL.path)
                let size = (attr[.size] as? Int64) ?? 0
                onProgress?(1.0, size, size)
            } else {
                // Network download via URLSession
                AppLogger.download.info("Iniciando descarga de red: \(downloadURL.absoluteString)")
                try await downloadWithRetry(
                    from: downloadURL,
                    to: tempIncomingURL,
                    jobId: job.id,
                    maxRetries: 2,
                    onProgress: onProgress
                )
            }

            // Step 1: Validate HTTP response and local file size
            do {
                try validator.validateLocalFile(at: tempIncomingURL)
            } catch {
                let failedTarget = organizer.failedDirectory.appendingPathComponent("failed-\(job.id.uuidString).pdf")
                try? FileManager.default.moveItem(at: tempIncomingURL, to: failedTarget)
                currentJob.downloadStatus = .failed
                currentJob.errorMessage = error.localizedDescription
                currentJob.completedAt = Date()
                return currentJob
            }

            // Step 2: Validate PDF Structure & Magic Bytes
            currentJob.downloadStatus = .validating
            let pdfValidation: PDFValidationResult
            do {
                pdfValidation = try PDFValidator.validate(at: tempIncomingURL)
            } catch {
                AppLogger.download.error("Validación de PDF fallida para \(job.id): \(error.localizedDescription)")
                // Move to Failed/ folder for diagnostic analysis
                let failedTarget = organizer.failedDirectory.appendingPathComponent("failed-\(job.id.uuidString).pdf")
                try? FileManager.default.moveItem(at: tempIncomingURL, to: failedTarget)

                currentJob.downloadStatus = .failed
                currentJob.errorMessage = "Validación PDF fallida: \(error.localizedDescription)"
                currentJob.completedAt = Date()
                return currentJob
            }

            // Step 3: Compute SHA-256 via streaming
            let sha256 = try FileHasher.sha256(for: tempIncomingURL)
            currentJob.sha256 = sha256
            currentJob.fileSize = pdfValidation.fileSize

            // Step 4: Extract Metadata
            let pdfMeta = PDFMetadataReader.readMetadata(from: tempIncomingURL)
            if currentJob.title == nil || currentJob.title?.isEmpty == true {
                currentJob.title = pdfMeta.title ?? suggestedFilename?.replacingOccurrences(of: ".pdf", with: "")
            }
            if currentJob.author == nil || currentJob.author?.isEmpty == true {
                currentJob.author = pdfMeta.author
            }

            // Step 5: Duplicate Detection and Filename Resolution
            let candidateFilename = FileOrganizer.formattedFilename(
                author: currentJob.author,
                title: currentJob.title,
                fallbackId: job.id.uuidString.prefix(8).description
            )

            let duplicateResolution = try DuplicateDetector.resolveDestination(
                desiredFilename: candidateFilename,
                sourceFileSize: pdfValidation.fileSize,
                sourceSHA256: sha256,
                destinationDirectory: organizer.libraryDirectory
            )

            let finalDestinationURL: URL
            switch duplicateResolution {
            case .exactDuplicate(let existingURL):
                AppLogger.filesystem.info("Documento idéntico ya presente en biblioteca: \(existingURL.path)")
                finalDestinationURL = existingURL
                currentJob.errorMessage = "Nota: Ya existía una copia idéntica en la biblioteca."
            case .uniqueDestination(let targetURL):
                AppLogger.filesystem.info("Moviendo archivo a biblioteca: \(targetURL.path)")
                try FileManager.default.moveItem(at: tempIncomingURL, to: targetURL)
                finalDestinationURL = targetURL
            }

            currentJob.localPath = finalDestinationURL.path
            currentJob.downloadStatus = .completed
            currentJob.progress = 1.0
            currentJob.bytesDownloaded = pdfValidation.fileSize
            currentJob.totalBytes = pdfValidation.fileSize
            currentJob.completedAt = Date()
            currentJob.mimeType = "application/pdf"

            return currentJob

        } catch is CancellationError {
            AppLogger.download.info("Descarga cancelada por el usuario para trabajo \(job.id)")
            currentJob.downloadStatus = .cancelled
            currentJob.errorMessage = "Descarga cancelada por el usuario."
            currentJob.completedAt = Date()
            return currentJob
        } catch {
            AppLogger.download.error("Descarga fallida para trabajo \(job.id): \(error.localizedDescription)")
            if FileManager.default.fileExists(atPath: tempIncomingURL.path) {
                let failedTarget = organizer.failedDirectory.appendingPathComponent("failed-\(job.id.uuidString).pdf")
                try? FileManager.default.moveItem(at: tempIncomingURL, to: failedTarget)
            }
            currentJob.downloadStatus = .failed
            currentJob.errorMessage = error.localizedDescription
            currentJob.completedAt = Date()
            return currentJob
        }
    }

    // MARK: - Internal Download with Retries
    private func downloadWithRetry(
        from url: URL,
        to targetTempURL: URL,
        jobId: UUID,
        maxRetries: Int,
        onProgress: (@Sendable (Double, Int64, Int64) -> Void)?
    ) async throws {
        var attempts = 0
        var lastError: Error?

        while attempts <= maxRetries {
            if Task.isCancelled || cancelledJobIds.contains(jobId) {
                throw CancellationError()
            }

            attempts += 1
            do {
                var request = URLRequest(url: url)
                request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

                try await withTaskCancellationHandler {
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        let downloadTask = self.session.downloadTask(with: request) { tempDownloadedURL, response, error in
                            if let error = error {
                                let ns = error as NSError
                                if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled {
                                    continuation.resume(throwing: CancellationError())
                                } else {
                                    continuation.resume(throwing: error)
                                }
                                return
                            }

                            guard let tempDownloadedURL = tempDownloadedURL, let response = response else {
                                continuation.resume(throwing: DownloadValidationError.missingResponse)
                                return
                            }

                            do {
                                try? FileManager.default.removeItem(at: targetTempURL)
                                try FileManager.default.moveItem(at: tempDownloadedURL, to: targetTempURL)
                                try self.validator.validateResponse(response)
                                continuation.resume()
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        }

                        self.activeDownloadTasks[jobId] = downloadTask
                        downloadTask.resume()
                    }
                } onCancel: {
                    Task {
                        await self.cancel(jobId: jobId)
                    }
                }

                let attr = try FileManager.default.attributesOfItem(atPath: targetTempURL.path)
                let size = (attr[.size] as? Int64) ?? 0
                onProgress?(1.0, size, size)
                return

            } catch is CancellationError {
                throw CancellationError()
            } catch let validationError as DownloadValidationError {
                // Non-transient validation failure, do not retry
                throw validationError
            } catch {
                lastError = error
                AppLogger.download.warning("Intento \(attempts)/\(maxRetries + 1) falló para \(url): \(error.localizedDescription)")
                if attempts <= maxRetries && !Task.isCancelled && !cancelledJobIds.contains(jobId) {
                    // Exponential backoff
                    try? await Task.sleep(nanoseconds: UInt64(attempts * 500_000_000))
                }
            }
        }

        if let error = lastError {
            throw error
        }
    }
}
