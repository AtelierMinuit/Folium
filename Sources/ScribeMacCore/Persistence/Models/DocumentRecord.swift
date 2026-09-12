import Foundation
import SwiftData

/// Persisted library document entry.
@Model
public final class DocumentRecord {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var author: String?
    public var sha256: String
    public var fileSize: Int64
    public var localPath: String
    public var mimeType: String
    public var canonicalURL: String?
    public var providerName: String
    public var pageCount: Int
    public var createdAt: Date
    public var addedAt: Date
    public var subject: String?
    public var isFavorite: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        author: String? = nil,
        sha256: String,
        fileSize: Int64,
        localPath: String,
        mimeType: String = "application/pdf",
        canonicalURL: String? = nil,
        providerName: String = "Desconocido",
        pageCount: Int = 1,
        createdAt: Date = Date(),
        addedAt: Date = Date(),
        subject: String? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.sha256 = sha256
        self.fileSize = fileSize
        self.localPath = localPath
        self.mimeType = mimeType
        self.canonicalURL = canonicalURL
        self.providerName = providerName
        self.pageCount = pageCount
        self.createdAt = createdAt
        self.addedAt = addedAt
        self.subject = subject
        self.isFavorite = isFavorite
    }
}
