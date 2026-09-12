import SwiftUI
import ScribeMacCore

/// Pantalla de captura vacía: se muestra cuando no hay trabajos en la cola.
/// Ofrece un campo de texto para pegar una URL, botones de acción y una zona de drop.
public struct EmptyCaptureView: View {
    @Environment(AppEnvironment.self) private var env
    @Bindable var model: AppModel
    @State private var isDropTargeted = false

    public var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Título principal
            VStack(spacing: 8) {
                Text("Scribe")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text("Descarga y organiza documentos fácilmente")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 16)

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
                .frame(maxWidth: 480)
                .disabled(model.inputURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.statusMessage != nil)

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
