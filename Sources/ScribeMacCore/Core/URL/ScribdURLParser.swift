import Foundation

/// Parsed metadata for a public Scribd URL.
public struct ScribdURLInfo: Sendable, Equatable {
    public let id: String
    public let slug: String?
    public let resourceType: String // "document", "presentation", etc.
    public let canonicalURL: URL

    public init(id: String, slug: String?, resourceType: String, canonicalURL: URL) {
        self.id = id
        self.slug = slug
        self.resourceType = resourceType
        self.canonicalURL = canonicalURL
    }
}

/// Specialized parser for public Scribd URLs.
/// Does NOT attempt to bypass any authentication, paywall, or DRM.
/// Identifies document IDs, slugs, and standardizes canonical URLs.
public struct ScribdURLParser: Sendable {

    /// Checks if the URL belongs to Scribd domains.
    public static func isScribdHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "scribd.com" || host.hasSuffix(".scribd.com")
    }

    /// Parses a Scribd URL and extracts ID, slug, resource type, and canonical URL.
    public static func parse(_ url: URL) -> ScribdURLInfo? {
        guard isScribdHost(url.host) else {
            return nil
        }

        let path = url.path

        // Pattern matching: /(document|doc|presentation|book)/(\d+)(?:/([a-zA-Z0-9_\-]+))?
        // Examples:
        // /document/123456789/trabajo-social
        // /doc/123456789/trabajo-social
        // /presentation/987654321/my-slides
        // /document/123456789
        let pattern = #"^/(document|doc|presentation|book)/([0-9]+)(?:/([a-zA-Z0-9_\-]+))?/?$"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(path.startIndex..<path.endIndex, in: path)
        guard let match = regex.firstMatch(in: path, options: [], range: range) else {
            return nil
        }

        guard let typeRange = Range(match.range(at: 1), in: path),
              let idRange = Range(match.range(at: 2), in: path) else {
            return nil
        }

        var rawType = String(path[typeRange]).lowercased()
        if rawType == "doc" {
            rawType = "document"
        }

        let id = String(path[idRange])

        var slug: String? = nil
        if match.numberOfRanges > 3, match.range(at: 3).location != NSNotFound,
           let sRange = Range(match.range(at: 3), in: path) {
            slug = String(path[sRange])
        }

        // Canonical format: https://www.scribd.com/{type}/{id}/{slug} or https://www.scribd.com/{type}/{id}
        var canonicalString = "https://www.scribd.com/\(rawType)/\(id)"
        if let slug = slug, !slug.isEmpty {
            canonicalString += "/\(slug)"
        }

        guard let canonicalURL = URL(string: canonicalString) else {
            return nil
        }

        return ScribdURLInfo(
            id: id,
            slug: slug,
            resourceType: rawType,
            canonicalURL: canonicalURL
        )
    }
}
