import Foundation
import FoliumCore

/// Categorías de la barra lateral de Folium (Folium UX).
public enum SidebarCategory: String, CaseIterable, Identifiable, Hashable {
    case biblioteca = "Biblioteca"
    case descargas = "Descargas"
    case cola = "En cola"
    case terminados = "Terminados"
    case errores = "Errores"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .biblioteca: return "books.vertical"
        case .descargas: return "arrow.down.circle"
        case .cola: return "clock"
        case .terminados: return "checkmark.circle"
        case .errores: return "exclamationmark.triangle"
        }
    }

    /// Filtra los jobs en vivo para la vista de cola.
    public func filter(jobs: [DocumentJob]) -> [DocumentJob] {
        switch self {
        case .biblioteca: 
            return [] // Biblioteca maneja sus propios datos persistidos
        case .descargas: 
            let now = Date()
            return jobs.filter { 
                $0.state == .resolvable || 
                $0.state == .downloading || 
                $0.state == .validating || 
                $0.state == .finalizing || 
                $0.state == .inspecting ||
                ($0.state == .completed && ($0.completedAt.map { now.timeIntervalSince($0) < 5 } ?? false))
            }
        case .cola: 
            return jobs.filter { $0.state == .queued }
        case .terminados: 
            return jobs.filter { $0.state == .completed }
        case .errores: 
            return jobs.filter { $0.state.isTerminal && $0.state != .completed }
        }
    }

    /// Cuenta los jobs que pertenecen a esta categoría.
    public func count(jobs: [DocumentJob]) -> Int {
        filter(jobs: jobs).count
    }
}
