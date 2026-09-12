import SwiftUI
import ScribeMacCore

/// Pantalla de captura vacía: se muestra cuando no hay trabajos en la cola.
/// Ofrece un campo de texto para pegar una URL, botones de acción y una zona de drop.
public struct EmptyCaptureView: View {
    @Environment(AppEnvironment.self) private var env
    @Bindable var model: AppModel
    @State private var isDropTargeted = false

    public var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icono principal
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, options: .repeating.speed(0.5))

            // Título y subtítulo
            VStack(spacing: 6) {
                Text("Pega un enlace de documento")
                    .font(.title2.bold())
                Text("Analiza, descarga y organiza documentos públicos de forma segura.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Campo de entrada + acciones
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .foregroundStyle(.secondary)

                    TextField("https://... o scribemac://fixture/...", text: $model.inputURL)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .onSubmit {
                            Task { await model.analyzeAndEnqueue(environment: env) }
                        }

                    if !model.inputURL.isEmpty {
                        Button {
                            model.inputURL = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isDropTargeted ? 2 : 1)
                )

                HStack(spacing: 12) {
                    Button {
                        model.pasteFromClipboard()
                    } label: {
                        Label("Pegar", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task { await model.analyzeAndEnqueue(environment: env) }
                    } label: {
                        if model.isAnalyzing {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Analizar", systemImage: "arrow.right.circle.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.inputURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isAnalyzing)
                }
            }
            .frame(maxWidth: 500)

            // Mensajes de error o estado
            if let error = model.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                .padding(10)
                .frame(maxWidth: 500, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let status = model.statusMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(status)
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
                .padding(10)
                .frame(maxWidth: 500, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Ejemplos rápidos
            HStack(spacing: 8) {
                Text("Ejemplos:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Scribd (Restringido)") {
                    model.setScribdSample()
                    Task { await model.analyzeAndEnqueue(environment: env) }
                }
                .buttonStyle(.link)
                .font(.caption)

                Text("•").font(.caption).foregroundStyle(.secondary)

                Button("arXiv (Abierto)") {
                    model.setArXivSample()
                    Task { await model.analyzeAndEnqueue(environment: env) }
                }
                .buttonStyle(.link)
                .font(.caption)

                Text("•").font(.caption).foregroundStyle(.secondary)

                Button("Fixture Local") {
                    model.setFixtureSample()
                    Task { await model.analyzeAndEnqueue(environment: env) }
                }
                .buttonStyle(.link)
                .font(.caption)
            }

            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.url, .plainText], isTargeted: $isDropTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    Task { @MainActor in
                        model.inputURL = url.absoluteString
                        await model.analyzeAndEnqueue(environment: env)
                    }
                }
            }
            return true
        }
    }

    /// Pega desde el portapapeles al campo de entrada (sin analizar).
    private func pasteFromClipboard() {
        if let string = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty {
            model.inputURL = string
        }
    }
}
