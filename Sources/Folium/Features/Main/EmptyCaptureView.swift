import SwiftUI
import FoliumCore

/// Pantalla de captura vacía: se muestra cuando no hay trabajos en la cola.
/// Ofrece un campo de texto para pegar una URL, botones de acción y una zona de drop.
public struct EmptyCaptureView: View {
    @Environment(AppEnvironment.self) private var env
    @Bindable var model: AppModel
    @State private var isDropTargeted = false

    public var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Identidad y Logotipo Oficial
            VStack(spacing: 12) {
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Color.blue.opacity(0.25), radius: 16, x: 0, y: 8)
                    .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)

                VStack(spacing: 4) {
                    Text("Folium")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("Encuentra. Obtén. Organiza.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 8)

            // Campo central
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "link")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    TextField("Pega aquí un enlace...", text: $model.inputURL)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .onSubmit {
                            Task { await model.analyzeURL(environment: env) }
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
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.15), lineWidth: isDropTargeted ? 2 : 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                .frame(maxWidth: 480)

                HStack(spacing: 8) {
                    Button {
                        Task { await model.analyzeURL(environment: env) }
                    } label: {
                        Text("Obtener documento")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(model.inputURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.statusMessage != nil)

                    if let clip = NSPasteboard.general.string(forType: .string)?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                       clip.hasPrefix("http://") || clip.hasPrefix("https://"),
                       model.inputURL.isEmpty {
                        Button {
                            model.inputURL = clip
                            Task { await model.analyzeURL(environment: env) }
                        } label: {
                            Label("Pegar enlace", systemImage: "doc.on.clipboard")
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .frame(maxWidth: 480)

                // Quick links educativos
                HStack(spacing: 8) {
                    Text("Ejemplos:")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Button("arXiv Open Access") {
                        model.inputURL = "https://arxiv.org/abs/2301.07041"
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.blue)

                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Button("Documento Fixture") {
                        model.setFixtureSample()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
                .padding(.top, 2)

                Text("o arrastra un enlace aquí")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }

            // Mensajes (ocultos si no hay)
            if let error = model.errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
                    .frame(maxWidth: 480)
            }

            if let status = model.statusMessage {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(status)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 16)
            }

            Spacer()
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
                        await model.analyzeURL(environment: env)
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
