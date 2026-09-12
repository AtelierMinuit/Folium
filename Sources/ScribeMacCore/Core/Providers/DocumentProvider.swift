import Foundation

public enum ProviderError: Error, LocalizedError, Equatable {
    case unhandledURL(URL)
    case resourceNotFound(URL)
    case restrictedResource(String)
    case authenticationRequired(String)
    case networkError(String)
    case invalidResponse(String)
    case unsupportedOperation(String)

    public var errorDescription: String? {
        switch self {
        case .unhandledURL(let url):
            return "El proveedor no puede procesar la URL: \(url.absoluteString)"
        case .resourceNotFound(let url):
            return "Recurso no encontrado en el servidor: \(url.absoluteString)"
        case .restrictedResource(let message):
            return "Recurso restringido: \(message)"
        case .authenticationRequired(let message):
            return "Se requiere autenticación: \(message)"
        case .networkError(let message):
            return "Error de red: \(message)"
        case .invalidResponse(let message):
            return "Respuesta no válida del proveedor: \(message)"
        case .unsupportedOperation(let message):
            return "Operación no soportada: \(message)"
        }
    }
}

/// Abstract contract for document source resolvers.
/// Allows adding new providers without coupling to a single site or architecture.
public protocol DocumentProvider: Sendable {
    /// Unique internal identifier (e.g. "scribd", "direct_pdf", "open_repository", "mock_fixture").
    var identifier: String { get }

    /// Human-readable display name.
    var displayName: String { get }

    /// Returns true if this provider is capable of processing the given URL.
    func canHandle(_ url: URL) -> Bool

    /// Inspects the URL and retrieves public metadata, canonical URL, and status.
    func inspect(_ url: URL) async throws -> ProviderResult

    /// Resolves the actual downloadable endpoint when authorized and allowed.
    func resolveDownload(_ url: URL) async throws -> DownloadResult
}
