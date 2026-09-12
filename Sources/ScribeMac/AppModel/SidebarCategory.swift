import Foundation
import ScribeMacCore

/// Categorías de la barra lateral de la Bandeja de ScribeMac.
/// Cada categoría filtra los trabajos según su estado en la máquina de estados.
public enum SidebarCategory: String, CaseIterable, Identifiable, Hashable {
    case todos = "Todos"
    case enCurso = "En curso"
    case cola = "Cola"
    case listos = "Listos"
    case errores = "Errores"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .todos: return "tray.full"
        case .enCurso: return "arrow.down.circle"
        case .cola: return "clock"
        case .listos: return "checkmark.circle"
        case .errores: return "exclamationmark.triangle"
        }
    }

    /// Filtra los jobs que pertenecen a esta categoría según el estado de la máquina de estados.
    public func filter(jobs: [DocumentJob]) -> [DocumentJob] {
        switch self {
        case .todos:
            return jobs
        case .enCurso:
            return jobs.filter { $0.state.isActive }
        case .cola:
            return jobs.filter { $0.state == .queued || $0.state == .received || $0.state == .resolvable }
        case .listos:
            return jobs.filter { $0.state == .completed }
        case .errores:
            return jobs.filter {
                $0.state == .failed || $0.state == .restricted ||
                $0.state == .unsupported || $0.state == .authenticationRequired ||
                $0.state == .cancelled
            }
        }
    }

    /// Cuenta los jobs que pertenecen a esta categoría.
    public func count(jobs: [DocumentJob]) -> Int {
        filter(jobs: jobs).count
    }
}
