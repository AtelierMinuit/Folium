import Foundation

/// Explicit state machine for document processing and download lifecycle.
/// Guarantees that states reflect technical realities rather than generic spinners.
public enum DocumentState: String, Codable, Sendable, CustomStringConvertible, CaseIterable {
    // Standard Linear Pipeline
    case received
    case parsing
    case inspecting
    case resolvable
    case queued
    case downloading
    case validating
    case finalizing
    case completed

    // Divergent / Error Branches
    case restricted
    case unsupported
    case authenticationRequired
    case cancelled
    case failed

    public var description: String {
        switch self {
        case .received: return "URL Recibida"
        case .parsing: return "Analizando URL"
        case .inspecting: return "Inspeccionando Recurso"
        case .resolvable: return "Recurso Resuelto"
        case .queued: return "En Cola"
        case .downloading: return "Descargando"
        case .validating: return "Validando PDF"
        case .finalizing: return "Finalizando y Hasheando"
        case .completed: return "Completado"
        case .restricted: return "Restringido (Sin descarga pública)"
        case .unsupported: return "No Soportado"
        case .authenticationRequired: return "Autenticación Requerida"
        case .cancelled: return "Cancelado"
        case .failed: return "Fallido"
        }
    }

    public var isActive: Bool {
        switch self {
        case .parsing, .inspecting, .queued, .downloading, .validating, .finalizing:
            return true
        default:
            return false
        }
    }

    public var isTerminal: Bool {
        switch self {
        case .completed, .restricted, .unsupported, .authenticationRequired, .cancelled, .failed:
            return true
        default:
            return false
        }
    }
}
