import Foundation
import Observation

@Observable
@MainActor
public final class DownloadQueue {
    public private(set) var jobs: [DocumentJob] = []
    public let downloadManager: DownloadManager

    private var activeTasks: [UUID: Task<Void, Never>] = [:]

    public init(downloadManager: DownloadManager = DownloadManager()) {
        self.downloadManager = downloadManager
    }

    /// Adds a recognized job to the queue without starting it.
    public func addRecognized(job: DocumentJob) {
        var mutableJob = job
        mutableJob.state = .resolvable
        mutableJob.recordTransition(.resolvable, message: "Documento reconocido y listo para descargar")
        jobs.insert(mutableJob, at: 0)
    }

    /// Starts processing a job that is already in the queue.
    public func startDownload(jobId: UUID, downloadURL: URL, suggestedFilename: String? = nil) {
        guard let idx = jobs.firstIndex(where: { $0.id == jobId }) else { return }
        
        jobs[idx].state = .queued
        jobs[idx].recordTransition(.queued, message: "Añadido a la cola de descargas")
        
        let mutableJob = jobs[idx]

        let task = Task { [weak self] in
            guard let self = self else { return }
            do {
                let updatedJob = try await self.downloadManager.execute(
                    job: mutableJob,
                    downloadURL: downloadURL,
                    suggestedFilename: suggestedFilename
                ) { [weak self] progress, downloaded, total in
                    Task { @MainActor [weak self] in
                        self?.updateProgress(jobId: jobId, progress: progress, downloaded: downloaded, total: total)
                    }
                }
                self.updateJob(updatedJob)
            } catch {
                self.failJob(jobId: jobId, error: error.localizedDescription)
            }
            self.activeTasks.removeValue(forKey: jobId)
        }

        activeTasks[jobId] = task
    }

    /// Enqueues a new document job and begins processing immediately (legacy).
    public func enqueue(job: DocumentJob, downloadURL: URL, suggestedFilename: String? = nil) {
        var mutableJob = job
        mutableJob.state = .queued
        jobs.insert(mutableJob, at: 0)
        startDownload(jobId: mutableJob.id, downloadURL: downloadURL, suggestedFilename: suggestedFilename)
    }

    /// Cancels a job.
    public func cancel(jobId: UUID) {
        activeTasks[jobId]?.cancel()
        activeTasks.removeValue(forKey: jobId)
        Task {
            await downloadManager.cancel(jobId: jobId)
        }
        if let idx = jobs.firstIndex(where: { $0.id == jobId }) {
            jobs[idx].downloadStatus = .cancelled
            jobs[idx].completedAt = Date()
        }
    }

    /// Retries a failed or cancelled job.
    public func retry(jobId: UUID) {
        guard let existing = jobs.first(where: { $0.id == jobId }),
              let sourceURL = existing.sourceURL ?? existing.canonicalURL else {
            return
        }
        cancel(jobId: jobId)
        enqueue(job: existing, downloadURL: sourceURL, suggestedFilename: existing.title)
    }

    private func updateProgress(jobId: UUID, progress: Double, downloaded: Int64, total: Int64) {
        if let idx = jobs.firstIndex(where: { $0.id == jobId }) {
            jobs[idx].progress = progress
            jobs[idx].bytesDownloaded = downloaded
            jobs[idx].totalBytes = total
            if jobs[idx].downloadStatus == .queued {
                jobs[idx].downloadStatus = .downloading
            }
        }
    }

    private func updateJob(_ updatedJob: DocumentJob) {
        if let idx = jobs.firstIndex(where: { $0.id == updatedJob.id }) {
            jobs[idx] = updatedJob
        }
    }

    private func failJob(jobId: UUID, error: String) {
        if let idx = jobs.firstIndex(where: { $0.id == jobId }) {
            jobs[idx].downloadStatus = .failed
            jobs[idx].errorMessage = error
            jobs[idx].completedAt = Date()
        }
    }
}
