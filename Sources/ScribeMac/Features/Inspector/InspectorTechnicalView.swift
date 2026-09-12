import SwiftUI
import ScribeMacCore
import AppKit

/// Panel de inspector técnico completo para un DocumentJob seleccionado.
/// Muestra ficha del documento, procedencia, archivo, red y timeline de transiciones.
public struct InspectorTechnicalView: View {
    let job: DocumentJob

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Cabecera
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(job.title ?? "Documento sin título")
                            .font(.headline)
                        if let author = job.author {
                            Text(author)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    StateBadgeView(state: job.state)
                }

                Divider()

                // Sección: Ficha
                inspectorSection("Ficha", icon: "doc.text") {
                    inspectorRow("Proveedor", value: job.provider?.capitalized ?? "—")
                    inspectorRow("Estado del recurso", value: job.resourceStatus.description)
                    inspectorRow("Estado técnico", value: job.state.description)
                    inspectorRow("Creado", value: formatDate(job.createdAt))
                    if let completedAt = job.completedAt {
                        inspectorRow("Completado", value: formatDate(completedAt))
                    }
                }

                Divider()

                // Sección: Procedencia
                inspectorSection("Procedencia", icon: "globe") {
                    copyableRow("URL Original", value: job.originalURL.absoluteString)
                    if let canonical = job.canonicalURL {
                        copyableRow("URL Canónica", value: canonical.absoluteString)
                    }
                    if let sourceURL = job.sourceURL {
                        copyableRow("URL de Descarga", value: sourceURL.absoluteString)
                    }
                }

                Divider()

                // Sección: Archivo
                inspectorSection("Archivo", icon: "doc") {
                    if let path = job.localPath {
                        copyableRow("Ruta Local", value: path)
                    }
                    if let size = job.fileSize {
                        inspectorRow("Tamaño", value: formatBytes(size))
                    }
                    if let mime = job.mimeType {
                        inspectorRow("Tipo MIME", value: mime)
                    }
                    if let sha = job.sha256 {
                        copyableRow("SHA-256", value: sha)
                    }
                    if let etag = job.etag {
                        inspectorRow("ETag", value: etag)
                    }
                    if let server = job.serverName {
                        inspectorRow("Servidor", value: server)
                    }
                    inspectorRow("Accept-Ranges", value: job.supportsRanges ? "bytes ✓" : "—")
                }

                Divider()

                // Sección: Red
                inspectorSection("Red", icon: "network") {
                    if job.speedBytesPerSecond > 0 {
                        inspectorRow("Velocidad", value: formatSpeed(job.speedBytesPerSecond))
                    }
                    if job.bytesDownloaded > 0 || job.totalBytes > 0 {
                        inspectorRow("Descargados", value: "\(formatBytes(job.bytesDownloaded)) de \(formatBytes(job.totalBytes))")
                    }
                    inspectorRow("Progreso", value: "\(Int(job.progress * 100))%")
                }

                if let error = job.errorMessage {
                    Divider()
                    inspectorSection("Error", icon: "exclamationmark.triangle") {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }

                Divider()

                // Sección: Detalles Técnicos (Timeline)
                inspectorSection("Detalles Técnicos", icon: "clock.arrow.circlepath") {
                    TransitionLogTimelineView(events: job.transitionLog)
                }

                // Botones de acción
                if job.state == .completed, let path = job.localPath {
                    Divider()
                    HStack(spacing: 12) {
                        Button {
                            NSWorkspace.shared.open(URL(fileURLWithPath: path))
                        } label: {
                            Label("Abrir", systemImage: "doc.text")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                        } label: {
                            Label("Mostrar en Finder", systemImage: "folder")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Componentes del Inspector

    @ViewBuilder
    private func inspectorSection<Content: View>(
        _ title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
            content()
        }
    }

    @ViewBuilder
    private func inspectorRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .trailing)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func copyableRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .trailing)
            HStack(spacing: 4) {
                Text(value)
                    .font(.system(.caption2, design: .monospaced))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)
                .help("Copiar al portapapeles")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Formateadores

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(bytesPerSecond)))/s"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "es")
        return formatter.string(from: date)
    }
}
