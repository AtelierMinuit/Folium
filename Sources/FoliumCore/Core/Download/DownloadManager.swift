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
            currentJob.recordTransition(.downloading, message: "Iniciando descarga de red en streaming...")

            // Handle file:// URLs (such as local fixtures)
            if downloadURL.isFileURL {
                AppLogger.download.info("Procesando recurso local fixture: \(downloadURL.path)")
                try FileManager.default.copyItem(at: downloadURL, to: tempIncomingURL)
                let attr = try FileManager.default.attributesOfItem(atPath: tempIncomingURL.path)
                let size = (attr[.size] as? Int64) ?? 0
                currentJob.recordTransition(.downloading, message: "Recurso local fixture cargado (\(size) bytes)")
                onProgress?(1.0, size, size)
            } else {
                // Network download via URLSession
                AppLogger.download.info("Iniciando descarga de red: \(downloadURL.absoluteString)")
                let headers = try await downloadWithRetry(
                    from: downloadURL,
                    to: tempIncomingURL,
                    jobId: job.id,
                    maxRetries: 2,
                    onProgress: onProgress
                )
                currentJob.etag = headers["ETag"]
                currentJob.serverName = headers["Server"]
                currentJob.supportsRanges = headers["Accept-Ranges"]?.lowercased().contains("bytes") == true
                currentJob.recordTransition(.downloading, message: "Respuesta HTTP recibida (Server: \(headers["Server"] ?? "desconocido"), ETag: \(headers["ETag"]?.prefix(8) ?? "ninguno"))")
            }

            // Step 1: Validate HTTP response and local file size
            do {
                try validator.validateLocalFile(at: tempIncomingURL)
            } catch {
                let failedTarget = organizer.failedDirectory.appendingPathComponent("failed-\(job.id.uuidString).pdf")
                try? FileManager.default.moveItem(at: tempIncomingURL, to: failedTarget)
                currentJob.recordTransition(.failed, message: "Validación de tamaño o HTTP fallida: \(error.localizedDescription)")
                currentJob.downloadStatus = .failed
                currentJob.errorMessage = error.localizedDescription
                currentJob.completedAt = Date()
                return currentJob
            }

            // Step 2: Validate PDF Structure & Magic Bytes
            currentJob.recordTransition(.validating, message: "Validando cabecera mágica %PDF- y estructura PDFKit...")
            currentJob.downloadStatus = .validating
            let pdfValidation: PDFValidationResult
            do {
                pdfValidation = try PDFValidator.validate(at: tempIncomingURL)
                currentJob.recordTransition(.validating, message: "PDF válido (%PDF-\(pdfValidation.pdfVersion ?? "1.4"), \(pdfValidation.pageCount) páginas legibles)")
            } catch {
                AppLogger.download.error("Validación de PDF fallida para \(job.id): \(error.localizedDescription)")
                let failedTarget = organizer.failedDirectory.appendingPathComponent("failed-\(job.id.uuidString).pdf")
                try? FileManager.default.moveItem(at: tempIncomingURL, to: failedTarget)

                currentJob.recordTransition(.failed, message: "Validación PDF fallida: \(error.localizedDescription)")
                currentJob.downloadStatus = .failed
                currentJob.errorMessage = "Validación PDF fallida: \(error.localizedDescription)"
                currentJob.completedAt = Date()
                return currentJob
            }

            // Step 3: Compute SHA-256 via streaming
            currentJob.recordTransition(.finalizing, message: "Calculando hash SHA-256 en bloques de 64 KB...")
            let sha256 = try FileHasher.sha256(for: tempIncomingURL)
            currentJob.sha256 = sha256
            currentJob.fileSize = pdfValidation.fileSize
            currentJob.recordTransition(.finalizing, message: "Hash SHA-256 generado: \(sha256.prefix(12))...")

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
                currentJob.recordTransition(.completed, message: "Copia idéntica existente reutilizada en Library/\(existingURL.lastPathComponent)")
            case .uniqueDestination(let targetURL):
                AppLogger.filesystem.info("Moviendo archivo a biblioteca: \(targetURL.path)")
                try FileManager.default.moveItem(at: tempIncomingURL, to: targetURL)
                finalDestinationURL = targetURL
                currentJob.recordTransition(.completed, message: "Archivo almacenado como Library/\(targetURL.lastPathComponent)")
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
            currentJob.recordTransition(.cancelled, message: "Descarga cancelada por el usuario.")
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
            currentJob.recordTransition(.failed, message: "Error en descarga: \(error.localizedDescription)")
            currentJob.downloadStatus = .failed
            currentJob.errorMessage = error.localizedDescription
            currentJob.completedAt = Date()
            return currentJob
        }
    }

    // MARK: - Internal Download with Retries
    /// Downloads the resource and returns HTTP response headers for metadata extraction.
    private func downloadWithRetry(
        from url: URL,
        to targetTempURL: URL,
        jobId: UUID,
        maxRetries: Int,
        onProgress: (@Sendable (Double, Int64, Int64) -> Void)?
    ) async throws -> [String: String] {
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

                let responseHeaders: [String: String] = try await withTaskCancellationHandler {
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: String], Error>) in
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

                                // Extract HTTP response headers
                                var headers: [String: String] = [:]
                                if let httpResponse = response as? HTTPURLResponse {
                                    for (key, value) in httpResponse.allHeaderFields {
                                        headers[String(describing: key)] = String(describing: value)
                                    }
                                }
                                continuation.resume(returning: headers)
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
                return responseHeaders

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

        // Fallback: should never reach here due to throw above
        return [:]
    }
}
