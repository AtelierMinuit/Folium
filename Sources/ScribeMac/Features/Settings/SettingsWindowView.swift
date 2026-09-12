import SwiftUI
import ScribeMacCore
import AppKit

/// Ventana de ajustes de ScribeMac, accesible mediante ⌘, (comando + coma).
/// Permite configurar la carpeta de descargas, tamaño máximo, portapapeles y ver información de la app.
public struct SettingsWindowView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var selectedDirectory: URL?
    @State private var showingDirectoryPicker = false

    public init() {}

    public var body: some View {
        @Bindable var env = env

        Form {
            // Sección: Almacenamiento
            Section("Almacenamiento") {
                LabeledContent("Carpeta de descargas") {
                    HStack {
                        Text(env.organizer.libraryDirectory.path)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)

                        Button("Cambiar...") {
                            showingDirectoryPicker = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                LabeledContent("Tamaño máximo de archivo") {
                    HStack {
                        Slider(
                            value: Binding(
                                get: { Double(env.maxFileSizeBytes) / (1024 * 1024) },
                                set: { env.maxFileSizeBytes = Int64($0 * 1024 * 1024) }
                            ),
                            in: 10...1000,
                            step: 10
                        )
                        .frame(width: 200)

                        Text("\(env.maxFileSizeBytes / (1024 * 1024)) MB")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .trailing)
                    }
                }
            }

            // Sección: Comportamiento
            Section("Comportamiento") {
                Toggle("Detectar URLs automáticamente en el portapapeles", isOn: $env.autoCheckClipboard)
                    .help("Cuando está activo, el MenuBarExtra detecta automáticamente URLs copiadas al portapapeles.")
            }

            // Sección: Acerca de
            Section("Acerca de") {
                LabeledContent("Aplicación") {
                    Text("ScribeMac")
                        .font(.headline)
                }
                LabeledContent("Versión") {
                    Text("1.0.0 (Educativa)")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Propósito") {
                    Text("Utilidad documental educativa para macOS")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Cumplimiento") {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("• Sin elusión de DRM")
                        Text("• Sin evasión de paywalls")
                        Text("• Sin resolución de CAPTCHAs")
                        Text("• Sin robo de credenciales")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 500, minHeight: 400)
        .fileImporter(
            isPresented: $showingDirectoryPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    env.updateDownloadDirectory(url)
                }
            case .failure:
                break
            }
        }
    }
}
