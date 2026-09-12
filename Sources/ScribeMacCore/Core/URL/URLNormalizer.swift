import Foundation

public enum URLErrorReason: Error, LocalizedError, Equatable {
    case emptyURL
    case invalidCharacters
    case unsupportedScheme(String)
    case missingHost
    case pathTraversalDetected
    case malformedURL

    public var errorDescription: String? {
        switch self {
        case .emptyURL:
            return "La URL no puede estar vacía."
        case .invalidCharacters:
            return "La URL contiene caracteres no válidos o de control."
        case .unsupportedScheme(let scheme):
            return "Esquema no admitido: '\(scheme)'. Se requiere HTTP, HTTPS o scribemac://."
        case .missingHost:
            return "La URL no tiene un nombre de host válido."
        case .pathTraversalDetected:
            return "Se detectó un intento de manipulación o path traversal en la URL."
        case .malformedURL:
            return "Formato de URL no válido."
        }
    }
}

/// Normalizes and cleans URLs: strips tracking parameters, standardizes host/path, and rejects insecure schemes.
public struct URLNormalizer: Sendable {
    private static let allowedSchemes: Set<String> = ["http", "https", "scribemac"]

    private static let trackingParams: Set<String> = [
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "fbclid", "gclid", "ref", "ref_src", "source", "feature", "context",
        "mc_cid", "mc_eid", "igshid", "_ga"
    ]

    public init() {}

    /// Normalizes an input URL string.
    public static func normalize(_ urlString: String) throws -> URL {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw URLErrorReason.emptyURL
        }

        // Check for control characters
        guard trimmed.rangeOfCharacter(from: CharacterSet.controlCharacters) == nil else {
            throw URLErrorReason.invalidCharacters
        }

        // Parse with URLComponents
        guard let components = URLComponents(string: trimmed) else {
            throw URLErrorReason.malformedURL
        }

        guard let scheme = components.scheme?.lowercased() else {
            throw URLErrorReason.malformedURL
        }

        guard allowedSchemes.contains(scheme) else {
            throw URLErrorReason.unsupportedScheme(scheme)
        }

        // Path traversal check
        let rawPath = components.percentEncodedPath
        if rawPath.contains("..") || rawPath.contains("%2e%2e") || rawPath.contains("%2E%2E") {
            throw URLErrorReason.pathTraversalDetected
        }

        var normalizedComponents = components
        normalizedComponents.scheme = scheme

        if let host = components.host {
            normalizedComponents.host = host.lowercased()
        } else if scheme != "scribemac" {
            throw URLErrorReason.missingHost
        }

        // Clean path: collapse multiple slashes
        var path = components.path
        while path.contains("//") {
            path = path.replacingOccurrences(of: "//", with: "/")
        }
        if path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        normalizedComponents.path = path

        // Filter tracking query items
        if let queryItems = components.queryItems, !queryItems.isEmpty {
            let filtered = queryItems.filter { !trackingParams.contains($0.name.lowercased()) }
            normalizedComponents.queryItems = filtered.isEmpty ? nil : filtered
        }

        // Remove fragments unless specifically needed
        normalizedComponents.fragment = nil

        guard let finalURL = normalizedComponents.url else {
            throw URLErrorReason.malformedURL
        }

        return finalURL
    }

    /// Convenience overload for existing URL
    public static func normalize(_ url: URL) throws -> URL {
        return try normalize(url.absoluteString)
    }
}
