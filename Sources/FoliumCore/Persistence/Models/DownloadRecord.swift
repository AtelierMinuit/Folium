import Foundation
import SwiftData

/// Persisted audit history entry for download jobs.
@Model
public final class DownloadRecord {
    @Attribute(.unique) public var id: UUID
    public var originalURL: String
    public var canonicalURL: String?
    public var provider: String
    public var title: String?
    public var author: String?
    public var resourceStatus: String
    public var downloadStatus: String
    public var createdAt: Date
    public var completedAt: Date?
    public var localPath: String?
    public var mimeType: String?
    public var fileSize: Int64?
    public var sha256: String?
    public var errorMessage: String?

    public init(
        id: UUID = UUID(),
        originalURL: String,
        canonicalURL: String? = nil,
        provider: String = "Desconocido",
        title: String? = nil,
        author: String? = nil,
        resourceStatus: String,
        downloadStatus: String,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        localPath: String? = nil,
        mimeType: String? = nil,
        fileSize: Int64? = nil,
        sha256: String? = nil,
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
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.localPath = localPath
        self.mimeType = mimeType
        self.fileSize = fileSize
        self.sha256 = sha256
        self.errorMessage = errorMessage
    }
}
