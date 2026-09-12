import SwiftUI
import ScribeMacCore
import AppKit

/// Vista popover del MenuBarExtra para añadir enlaces rápidamente
/// sin abrir la ventana principal de ScribeMac.
public struct MenuBarCompanionView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var inputURL: String = ""
    @State private var detectedClipboardURL: String?
    @State private var statusMessage: String?
    @State private var isProcessing: Bool = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Cabecera
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(.tint)
                Text("ScribeMac")
                    .font(.headline)
                Spacer()
            }

            Divider()

            // Detección de URL en portapapeles
            if let clipURL = detectedClipboardURL {
                HStack {
                    Image(systemName: "clipboard")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text("URL detectada en portapapeles")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(clipURL)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding(8)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))

                Button {
                    inputURL = clipURL
                    Task { await quickAnalyze() }
                } label: {
                    Label("Pegar y Analizar", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            // Campo de entrada manual
            HStack(spacing: 6) {
                TextField("Pegar URL...", text: $inputURL)
                    .textFieldStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
                    .onSubmit { Task { await quickAnalyze() } }

                Button {
                    Task { await quickAnalyze() }
                } label: {
                    if isProcessing {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(inputURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Mensaje de estado
            if let status = statusMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(status)
                        .font(.caption)
                }
            }

            Divider()

            // Resumen de transferencias activas (máximo 5)
            let activeJobs = env.queue.jobs.filter { $0.state.isActive }.prefix(5)
            if !activeJobs.isEmpty {
                Text("Transferencias activas")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                ForEach(Array(activeJobs)) { job in
                    HStack(spacing: 6) {
                        ProgressView(value: job.progress)
                            .progressViewStyle(.linear)
                            .frame(width: 60)
                        Text(job.title ?? "Sin título")
                            .font(.caption2)
                            .lineLimit(1)
                        Spacer()
                        Text("\(Int(job.progress * 100))%")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Resumen de completados recientes
            let recentCompleted = env.queue.jobs.filter { $0.state == .completed }.prefix(3)
            if !recentCompleted.isEmpty {
                Text("Completados recientes")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                ForEach(Array(recentCompleted)) { job in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption2)
                        Text(job.title ?? "Sin título")
                            .font(.caption2)
                            .lineLimit(1)
                    }
                }
            }

            Divider()

            // Abrir ventana principal
            Button {
                NSApplication.shared.activate(ignoringOtherApps: true)
                if let window = NSApplication.shared.windows.first(where: { $0.title.contains("ScribeMac") || $0.isKeyWindow }) {
                    window.makeKeyAndOrderFront(nil)
                }
            } label: {
                Label("Abrir ScribeMac", systemImage: "macwindow")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .frame(width: 300)
        .onAppear {
            detectClipboardURL()
        }
    }

    // MARK: - Lógica

    private func detectClipboardURL() {
        if let string = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           let url = URL(string: string),
           url.scheme == "http" || url.scheme == "https" || url.scheme == "scribemac" {
            detectedClipboardURL = string
        } else {
            detectedClipboardURL = nil
        }
    }

    private func quickAnalyze() async {
        let trimmed = inputURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let normalizedURL = try URLNormalizer.normalize(trimmed)
            guard let provider = env.registry.provider(for: normalizedURL) else {
                statusMessage = "Proveedor no encontrado"
                return
            }

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
                env.queue.enqueue(
                    job: job,
                    downloadURL: downloadResolution.url,
                    suggestedFilename: downloadResolution.suggestedFilename
                )
                statusMessage = "✓ Añadido a la cola"
                inputURL = ""
            } else {
                statusMessage = "Recurso: \(result.resourceStatus.description)"
            }
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
    }
}
