import Foundation

/// Output of a provider inspection on an input URL.
public struct ProviderResult: Sendable, Equatable {
    public let providerIdentifier: String
    public let originalURL: URL
    public let canonicalURL: URL
    public let resourceStatus: ResourceStatus
    public let metadata: DocumentMetadata
    public let downloadableURL: URL?
    public let publicId: String?
    public let slug: String?
    public let note: String?

    public init(
        providerIdentifier: String,
        originalURL: URL,
        canonicalURL: URL,
        resourceStatus: ResourceStatus,
        metadata: DocumentMetadata = DocumentMetadata(),
        downloadableURL: URL? = nil,
        publicId: String? = nil,
        slug: String? = nil,
        note: String? = nil
    ) {
        self.providerIdentifier = providerIdentifier
        self.originalURL = originalURL
        self.canonicalURL = canonicalURL
        self.resourceStatus = resourceStatus
        self.metadata = metadata
        self.downloadableURL = downloadableURL
        self.publicId = publicId
        self.slug = slug
        self.note = note
    }
}
