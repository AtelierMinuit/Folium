import SwiftUI
import Observation
import ScribeMacCore
import AppKit

/// Modelo central de la interfaz de usuario de ScribeMac.
/// Coordina el estado de la UI, la selección, los filtros y las acciones del usuario.
@Observable
@MainActor
public final class AppModel {
    // MARK: - Estado de Selección y Navegación

    public var selectedCategory: SidebarCategory = .todos
    public var selectedJobId: UUID?
    public var searchText: String = ""
    public var isInspectorPresented: Bool = false

    // MARK: - Estado de Captura

    public var inputURL: String = ""
    public var isAnalyzing: Bool = false
    public var errorMessage: String?
    public var statusMessage: String?

    public init() {}

    // MARK: - Propiedades Computadas

    /// Jobs filtrados según la categoría seleccionada y el texto de búsqueda.
    public func filteredJobs(from queue: DownloadQueue) -> [DocumentJob] {
        var jobs = selectedCategory.filter(jobs: queue.jobs)
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            jobs = jobs.filter { job in
                (job.title?.lowercased().contains(query) ?? false) ||
                (job.author?.lowercased().contains(query) ?? false) ||
                job.originalURL.absoluteString.lowercased().contains(query) ||
                (job.provider?.lowercased().contains(query) ?? false)
            }
        }
        return jobs
    }

    /// Job actualmente seleccionado.
    public func selectedJob(from queue: DownloadQueue) -> DocumentJob? {
        guard let id = selectedJobId else { return nil }
        return queue.jobs.first { $0.id == id }
    }

    // MARK: - Conteos para la Barra Lateral

    public func badgeCount(for category: SidebarCategory, queue: DownloadQueue) -> Int {
        category.count(jobs: queue.jobs)
    }

    /// Velocidad agregada de todas las transferencias activas (bytes/segundo).
    public func activeBytesPerSecond(queue: DownloadQueue) -> Double {
        queue.jobs
            .filter { $0.state == .downloading }
            .reduce(0.0) { $0 + $1.speedBytesPerSecond }
    }

    /// Total de bytes descargados en la sesión.
    public func totalBytesDownloaded(queue: DownloadQueue) -> Int64 {
        queue.jobs.reduce(Int64(0)) { $0 + $1.bytesDownloaded }
    }

    /// Número de transferencias activas.
    public func activeTransferCount(queue: DownloadQueue) -> Int {
        queue.jobs.filter { $0.state.isActive }.count
    }

    // MARK: - Acciones

    /// Analiza una URL y crea un trabajo en la cola si es descargable.
    public func analyzeAndEnqueue(environment: AppEnvironment) async {
        let trimmedInput = inputURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            errorMessage = "Introduce o pega una URL para comenzar."
            return
        }

        errorMessage = nil
        statusMessage = nil
        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            let normalizedURL = try URLNormalizer.normalize(trimmedInput)
            guard let provider = environment.registry.provider(for: normalizedURL) else {
                errorMessage = "No se encontró ningún proveedor compatible para esta URL."
                return
            }

            AppLogger.general.info("Analizando URL con proveedor: \(provider.displayName)")
            let result = try await provider.inspect(normalizedURL)

            let job = DocumentJob(
                originalURL: result.originalURL,
                canonicalURL: result.canonicalURL,
                provider: result.providerIdentifier,
                title: result.metadata.title,
                author: result.metadata.author,
                resourceStatus: result.resourceStatus,
                state: .inspecting,
                fileSize: result.metadata.fileSize
            )

            if result.resourceStatus.isActionable {
                let downloadResolution = try await provider.resolveDownload(result.canonicalURL)
                environment.queue.enqueue(
                    job: job,
                    downloadURL: downloadResolution.url,
                    suggestedFilename: downloadResolution.suggestedFilename
                )
                statusMessage = "Descarga añadida a la cola."
                inputURL = ""
            } else {
                errorMessage = "Recurso clasificado como '\(result.resourceStatus.description)'. No se puede descargar."
            }

            try? environment.store.recordDownload(from: job)

        } catch {
            AppLogger.general.error("Error al analizar: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// Pega la URL del portapapeles en el campo de entrada sin analizar.
    public func pasteFromClipboard() {
        if let string = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty {
            inputURL = string
        }
    }

    /// Pega el contenido del portapapeles y analiza automáticamente.
    public func pasteAndAnalyze(environment: AppEnvironment) async {
        if let string = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty {
            inputURL = string
            await analyzeAndEnqueue(environment: environment)
        }
    }

    /// Cancela un trabajo.
    public func cancel(id: UUID, queue: DownloadQueue) {
        queue.cancel(jobId: id)
    }

    /// Reintenta un trabajo fallido o cancelado.
    public func retry(id: UUID, queue: DownloadQueue) {
        queue.retry(jobId: id)
    }

    /// Abre el documento completado en la aplicación por defecto.
    public func openDocument(id: UUID, queue: DownloadQueue) {
        guard let job = queue.jobs.first(where: { $0.id == id }),
              let path = job.localPath else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    /// Muestra el documento en Finder.
    public func openInFinder(id: UUID, queue: DownloadQueue) {
        guard let job = queue.jobs.first(where: { $0.id == id }),
              let path = job.localPath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    /// Carga un enlace de ejemplo educativo.
    public func setFixtureSample() {
        inputURL = "scribemac://fixture/document/sample-educativo"
    }

    public func setArXivSample() {
        inputURL = "https://arxiv.org/abs/2301.00001"
    }

    public func setScribdSample() {
        inputURL = "https://www.scribd.com/document/123456789/trabajo-social"
    }
}
