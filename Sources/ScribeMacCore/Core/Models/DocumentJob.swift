import Foundation

/// Lifecycle status for a document processing / download job.
public enum DownloadStatus: String, Codable, Sendable, CustomStringConvertible {
    case idle
    case inspecting
    case queued
    case downloading
    case validating
    case completed
    case failed
    case cancelled

    public var description: String {
        switch self {
        case .idle: return "En espera"
        case .inspecting: return "Analizando"
        case .queued: return "En cola"
        case .downloading: return "Descargando"
        case .validating: return "Validando"
        case .completed: return "Completado"
        case .failed: return "Fallido"
        case .cancelled: return "Cancelado"
        }
    }
}

/// A comprehensive job tracking the complete lifecycle of a document processing request.
public struct DocumentJob: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public let originalURL: URL
    public var canonicalURL: URL?
    public var provider: String?
    public var title: String?
    public var author: String?
    public var resourceStatus: ResourceStatus
    public var downloadStatus: DownloadStatus
    public var progress: Double // 0.0 to 1.0
    public var bytesDownloaded: Int64
    public var totalBytes: Int64
    public var createdAt: Date
    public var completedAt: Date?
    public var localPath: String?
    public var mimeType: String?
    public var fileSize: Int64?
    public var sha256: String?
    public var sourceURL: URL?
    public var errorMessage: String?

    public init(
        id: UUID = UUID(),
        originalURL: URL,
        canonicalURL: URL? = nil,
        provider: String? = nil,
        title: String? = nil,
        author: String? = nil,
        resourceStatus: ResourceStatus = .downloadable,
        downloadStatus: DownloadStatus = .idle,
        progress: Double = 0.0,
        bytesDownloaded: Int64 = 0,
        totalBytes: Int64 = 0,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        localPath: String? = nil,
        mimeType: String? = nil,
        fileSize: Int64? = nil,
        sha256: String? = nil,
        sourceURL: URL? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.originalURL = originalURL
        self.canonicalURL = canonicalURL
        self.provider = provider
        self.title = title
        self.author = author
        self.resourceStatus = resourceStatus
        self.downloadStatus = downloadStatus
        self.progress = progress
        self.bytesDownloaded = bytesDownloaded
        self.totalBytes = totalBytes
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.localPath = localPath
        self.mimeType = mimeType
        self.fileSize = fileSize
        self.sha256 = sha256
        self.sourceURL = sourceURL
        self.errorMessage = errorMessage
    }
}
