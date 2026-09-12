import Foundation

/// Resolution details for a downloadable resource.
public struct DownloadResult: Sendable, Equatable {
    public let url: URL
    public let suggestedFilename: String?
    public let expectedMIMEType: String?
    public let requiresAuthentication: Bool

    public init(
        url: URL,
        suggestedFilename: String? = nil,
        expectedMIMEType: String? = nil,
        requiresAuthentication: Bool = false
    ) {
        self.url = url
        self.suggestedFilename = suggestedFilename
        self.expectedMIMEType = expectedMIMEType
        self.requiresAuthentication = requiresAuthentication
    }
}
