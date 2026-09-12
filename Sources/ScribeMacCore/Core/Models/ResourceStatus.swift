import Foundation

/// Represents the technical status of a document resource discovered from a URL.
public enum ResourceStatus: String, Codable, Sendable, CustomStringConvertible {
    /// The resource has an authorized or public direct link that can be downloaded.
    case downloadable

    /// Only public metadata (e.g. title, author, description) could be retrieved; no authorized download exists.
    case metadataOnly

    /// The resource explicitly requires user credentials or an active authenticated session.
    case authenticationRequired

    /// The resource is protected or access-controlled without authorized public download.
    case restricted

    /// The URL format or domain is not supported by any registered provider.
    case unsupported

    /// The remote endpoint returned 404, DNS error, network timeout, or server error.
    case unavailable

    public var description: String {
        switch self {
        case .downloadable:
            return "Descargable"
        case .metadataOnly:
            return "Solo Metadatos"
        case .authenticationRequired:
            return "Requiere Autenticación"
        case .restricted:
            return "Restringido (Sin descarga pública)"
        case .unsupported:
            return "No Soportado"
        case .unavailable:
            return "No Disponible"
        }
    }

    public var isActionable: Bool {
        return self == .downloadable
    }
}
