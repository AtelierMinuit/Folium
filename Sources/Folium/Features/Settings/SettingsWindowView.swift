import SwiftUI
import FoliumCore
import AppKit

/// Ventana de ajustes de Folium, accesible mediante ⌘, (comando + coma).
/// Permite configurar la carpeta de descargas, tamaño máximo, portapapeles y ver información de la app.
public struct SettingsWindowView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var selectedDirectory: URL?
    @AppStorage("maxConcurrentDownloads") private var maxConcurrent = 3
    @AppStorage("afterDownloadAction") private var afterAction = "notification"
    @AppStorage("fetchCoverAuto") private var fetchCover = true
    @AppStorage("showNotification") private var showNotification = true
    @State private var showingDirectoryPicker = false

    public init() {}

    public var body: some View {
        @Bindable var env = env

        TabView {
            // Pestaña: General
            Form {
                Section("Notificaciones") {
                    Toggle("Mostrar notificación al terminar la descarga", isOn: $showNotification)
                }

                Section("Acción Posterior") {
                    Picker("Después de descargar", selection: $afterAction) {
                        Text("Abrir documento en visor").tag("open")
                        Text("Solo mostrar notificación").tag("notification")
                    }
                    .pickerStyle(.radioGroup)
                }

                Section("Portapapeles") {
                    Toggle("Detectar URLs automáticamente en el portapapeles", isOn: $env.autoCheckClipboard)
                }
            }
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
            .formStyle(.grouped)
            .padding()

            // Pestaña: Descargas
            Form {
                Section("Concurrencia y Capacidad") {
                    Stepper(value: $maxConcurrent, in: 1...10) {
                        Text("Descargas simultáneas: \(maxConcurrent)")
                    }

                    LabeledContent("Límite de tamaño") {
                        HStack {
                            Slider(
                                value: Binding(
                                    get: { Double(env.maxFileSizeBytes) / (1024 * 1024) },
                                    set: { env.maxFileSizeBytes = Int64($0 * 1024 * 1024) }
                                ),
                                in: 10...1000,
                                step: 10
                            )
                            .frame(width: 180)

                            Text("\(env.maxFileSizeBytes / (1024 * 1024)) MB")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }

                Section("Metadatos y Portadas") {
                    Toggle("Obtener portada automáticamente al procesar", isOn: $fetchCover)
                }
            }
            .tabItem {
                Label("Descargas", systemImage: "arrow.down.circle")
            }
            .formStyle(.grouped)
            .padding()

            // Pestaña: Biblioteca
            Form {
                Section("Ubicación en Disco") {
                    LabeledContent("Directorio de Biblioteca") {
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
                }

                Section("Políticas de Archivo") {
                    LabeledContent("Deduplicación") {
                        Text("Automática por hash SHA-256 criptográfico")
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Sanitización") {
                        Text("POSIX/macOS seguro (sin path traversal)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .tabItem {
                Label("Biblioteca", systemImage: "books.vertical")
            }
            .formStyle(.grouped)
            .padding()

            // Pestaña: Privacidad
            Form {
                Section("Compromiso de Privacidad") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Procesamiento 100% Local", systemImage: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                            .font(.headline)
                        Text("Folium no envía tus enlaces, títulos, historial, hashes ni archivos a servidores de analítica, telemetría ni servicios externos de terceros.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Divider().padding(.vertical, 4)

                        Text("• App Sandbox de macOS activo y verificado")
                        Text("• Hardened Runtime habilitado")
                        Text("• Sin rastreadores ni perfiles de usuario")
                        Text("• Cero almacenamiento de contraseñas ni tokens")
                    }
                    .font(.caption)
                }
            }
            .tabItem {
                Label("Privacidad", systemImage: "hand.raised")
            }
            .formStyle(.grouped)
            .padding()

            // Pestaña: Avanzado
            Form {
                Section("Acerca de Folium") {
                    LabeledContent("Versión") {
                        Text("1.0.0 (Producción)")
                    }
                    LabeledContent("Arquitectura") {
                        Text("Apple Silicon nativo (arm64)")
                    }
                    LabeledContent("Identificador") {
                        Text("cl.jorgemunoz.folium")
                            .font(.system(.caption, design: .monospaced))
                    }
                }

                Section("Cumplimiento y Términos") {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("• Sin elusión de DRM ni alteración de cifrado")
                        Text("• Sin evasión de paywalls ni paywall scrapers")
                        Text("• Sin resolución automatizada de CAPTCHAs")
                        Text("• Sin apropiación de credenciales")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .tabItem {
                Label("Avanzado", systemImage: "info.circle")
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(width: 520, height: 380)
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
