import Foundation

/// Structured metadata describing a document.
public struct DocumentMetadata: Sendable, Codable, Equatable {
    public var title: String?
    public var author: String?
    public var subject: String?
    public var creator: String?
    public var producer: String?
    public var pageCount: Int?
    public var fileSize: Int64?
    public var contentType: String?
    public var creationDate: Date?
    public var modificationDate: Date?
    public var keywords: [String]
    public var isEncrypted: Bool
    public var language: String?

    public init(
        title: String? = nil,
        author: String? = nil,
        subject: String? = nil,
        creator: String? = nil,
        producer: String? = nil,
        pageCount: Int? = nil,
        fileSize: Int64? = nil,
        contentType: String? = nil,
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        keywords: [String] = [],
        isEncrypted: Bool = false,
        language: String? = nil
    ) {
        self.title = title
        self.author = author
        self.subject = subject
        self.creator = creator
        self.producer = producer
        self.pageCount = pageCount
        self.fileSize = fileSize
        self.contentType = contentType
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.keywords = keywords
        self.isEncrypted = isEncrypted
        self.language = language
    }
}
