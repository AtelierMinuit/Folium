import SwiftUI
import Observation
import FoliumCore
import AppKit

@Observable
@MainActor
public final class HomeViewModel {
    public var inputURL: String = ""
    public var isAnalyzing: Bool = false
    public var isDownloading: Bool = false
    public var inspectionResult: ProviderResult?
    public var currentJob: DocumentJob?
    public var errorMessage: String?
    public var statusMessage: String?

    public init() {}

    public func analyze(environment: AppEnvironment) async {
        guard !inputURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Introduce o pega una URL para comenzar."
            return
        }

        errorMessage = nil
        statusMessage = nil
        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            let normalizedURL = try URLNormalizer.normalize(inputURL)
            guard let provider = environment.registry.provider(for: normalizedURL) else {
                errorMessage = "No se encontró ningún proveedor compatible para esta URL."
                return
            }

            AppLogger.general.info("Analizando URL con proveedor: \(provider.displayName)")
            let result = try await provider.inspect(normalizedURL)
            self.inspectionResult = result

            let job = DocumentJob(
                originalURL: result.originalURL,
                canonicalURL: result.canonicalURL,
                provider: result.providerIdentifier,
                title: result.metadata.title,
                author: result.metadata.author,
                resourceStatus: result.resourceStatus,
                downloadStatus: .idle,
                fileSize: result.metadata.fileSize
            )
            self.currentJob = job

            // Record initial audit entry
            try? environment.store.recordDownload(from: job)

        } catch {
            AppLogger.general.error("Error al analizar: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            inspectionResult = nil
            currentJob = nil
        }
    }

    public func startDownload(environment: AppEnvironment) async {
        guard let result = inspectionResult, let job = currentJob else { return }

        guard result.resourceStatus.isActionable else {
            errorMessage = "Este recurso está clasificado como '\(result.resourceStatus.description)'. No se puede iniciar la descarga directa."
            return
        }

        guard let provider = environment.registry.provider(for: result.canonicalURL) else {
            errorMessage = "Proveedor no disponible."
            return
        }

        errorMessage = nil
        isDownloading = true

        do {
            let downloadResolution = try await provider.resolveDownload(result.canonicalURL)
            environment.queue.enqueue(
                job: job,
                downloadURL: downloadResolution.url,
                suggestedFilename: downloadResolution.suggestedFilename
            )
            statusMessage = "Descarga añadida a la cola."
        } catch {
            errorMessage = error.localizedDescription
        }

        isDownloading = false
    }

    public func pasteFromClipboard() {
        if let string = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty {
            inputURL = string
        }
    }

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
