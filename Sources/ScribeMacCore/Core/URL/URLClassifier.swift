import Foundation

public enum URLCategory: String, Sendable, Codable, CustomStringConvertible {
    case scribd
    case directPDF
    case openRepository
    case fixture
    case unknown

    public var description: String {
        switch self {
        case .scribd: return "Scribd"
        case .directPDF: return "PDF Directo"
        case .openRepository: return "Repositorio Abierto"
        case .fixture: return "Fixture de Pruebas"
        case .unknown: return "Desconocido"
        }
    }
}

/// Classifies URLs into specific functional categories to route to appropriate providers.
public struct URLClassifier: Sendable {

    public static func classify(_ url: URL) -> URLCategory {
        // Fixture scheme
        if url.scheme?.lowercased() == "scribemac" && (url.host == "fixture" || url.path.hasPrefix("/fixture")) {
            return .fixture
        }

        // Scribd
        if ScribdURLParser.isScribdHost(url.host) {
            return .scribd
        }

        // Open repositories (e.g. arXiv)
        if let host = url.host?.lowercased() {
            if host == "arxiv.org" || host.hasSuffix(".arxiv.org") {
                return .openRepository
            }
        }

        // Direct PDF extension check
        let pathExtension = url.pathExtension.lowercased()
        if pathExtension == "pdf" {
            return .directPDF
        }

        // If path or query explicitly points to .pdf
        if url.path.lowercased().hasSuffix(".pdf") {
            return .directPDF
        }

        return .unknown
    }
}
