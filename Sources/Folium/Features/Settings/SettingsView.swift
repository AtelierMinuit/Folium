import SwiftUI
import FoliumCore
import AppKit

public struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var showingClearConfirmation = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Title
                VStack(alignment: .leading, spacing: 4) {
                    Text("Configuración y Preferencias")
                        .font(.title2.bold())
                    Text("Gestiona las rutas de almacenamiento, límites de seguridad y auditoría.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Storage Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Almacenamiento Local")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Carpeta principal de descargas:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack {
                            Text(env.organizer.rootDirectory.path)
                                .font(.system(.caption, design: .monospaced))
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                            Button("Cambiar...") {
                                chooseDirectory()
                            }
                            .buttonStyle(.bordered)

                            Button("Abrir en Finder") {
                                NSWorkspace.shared.open(env.organizer.rootDirectory)
                            }
                            .buttonStyle(.bordered)
                        }

                        Text("Estructura interna: Incoming/ (descargas en curso), Library/ (validados), Failed/ (rechazados), Logs/.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // Security and Limits
                VStack(alignment: .leading, spacing: 12) {
                    Text("Límites de Seguridad")
                        .font(.headline)

                    HStack {
                        Text("Tamaño máximo permitido:")
                            .font(.subheadline)
                        Spacer()
                        Picker("", selection: Bindable(env).maxFileSizeBytes) {
                            Text("50 MB").tag(Int64(50 * 1024 * 1024))
                            Text("100 MB").tag(Int64(100 * 1024 * 1024))
                            Text("250 MB (Recomendado)").tag(Int64(250 * 1024 * 1024))
                            Text("500 MB").tag(Int64(500 * 1024 * 1024))
                            Text("1 GB").tag(Int64(1024 * 1024 * 1024))
                        }
                        .frame(width: 220)
                    }

                    Toggle("Detección automática del portapapeles al activar la ventana", isOn: Bindable(env).autoCheckClipboard)
                        .font(.subheadline)
                    Text("Por respeto a la privacidad del usuario, esta opción requiere activación explícita y nunca registra contraseñas ni datos privados.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Privacy & Ethical Compliance Box
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "shield.lefthalf.filled")
                            .foregroundStyle(.tint)
                        Text("Principios de Seguridad y Cumplimiento Ético")
                            .font(.headline)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        bulletPoint("Propósito Educativo: estudio de arquitectura de software, validación PDF y persistencia.")
                        bulletPoint("Sin vulneración de DRM, paywalls, CAPTCHAs ni ingeniería inversa de APIs privadas.")
                        bulletPoint("Los recursos protegidos quedan clasificados técnicamente como 'Restringidos'.")
                        bulletPoint("Validación estricta de Magic Bytes (%PDF-), evitando ejecución de HTML malicioso disfrazado.")
                        bulletPoint("Deduplicación criptográfica basada en SHA-256 + tamaño.")
                        bulletPoint("Privilegios mínimos: sin sudo, sin modificación de SIP, TCC ni cuarentenas del sistema.")
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Divider()

                // Data Management
                VStack(alignment: .leading, spacing: 10) {
                    Text("Mantenimiento y Auditoría")
                        .font(.headline)

                    Button("Limpiar Registro de Descargas", role: .destructive) {
                        showingClearConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .confirmationDialog("¿Limpiar todo el historial de descargas?", isPresented: $showingClearConfirmation) {
                        Button("Limpiar Historial", role: .destructive) {
                            try? env.store.clearDownloads()
                        }
                        Button("Cancelar", role: .cancel) {}
                    } message: {
                        Text("Esta acción eliminará el historial de auditoría de descargas en SwiftData. Los archivos en tu biblioteca no serán eliminados.")
                    }
                }

                Spacer()
            }
            .padding(24)
        }
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Seleccionar Carpeta"

        if panel.runModal() == .OK, let selectedURL = panel.url {
            env.updateDownloadDirectory(selectedURL)
        }
    }
}
