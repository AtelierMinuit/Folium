import SwiftUI
import ScribeMacCore
import AppKit

/// Tarjeta visual individual para un DocumentJob.
/// Muestra miniatura, título, autor, estado, progreso y acciones contextuales.
public struct JobCardView: View {
    @Environment(AppEnvironment.self) private var env
    let job: DocumentJob
    let model: AppModel

    @State private var thumbnailImage: NSImage?

    public var body: some View {
        HStack(spacing: 12) {
            // Miniatura o icono de placeholder
            thumbnailView
                .frame(width: 48, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            // Contenido central
            VStack(alignment: .leading, spacing: 4) {
                Text(job.title ?? "Documento sin título")
                    .font(.headline)
                    .lineLimit(1)

                if let author = job.author, !author.isEmpty {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    // Badge de estado
                    StateBadgeView(state: job.state)

                    if let provider = job.provider {
                        Text(provider.capitalized)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                // Barra de progreso si está descargando
                if job.state == .downloading || job.state == .validating || job.state == .finalizing {
                    ProgressView(value: job.progress)
                        .progressViewStyle(.linear)

                    HStack {
                        if job.totalBytes > 0 {
                            Text("\(formatBytes(job.bytesDownloaded)) de \(formatBytes(job.totalBytes))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if job.speedBytesPerSecond > 0 {
                            Text("\(formatSpeed(job.speedBytesPerSecond))")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }

            Spacer()

            // Metadatos a la derecha
            VStack(alignment: .trailing, spacing: 4) {
                if let size = job.fileSize {
                    Text(formatBytes(size))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let completedAt = job.completedAt {
                    Text(completedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            contextMenuItems
        }
        .task {
            await loadThumbnail()
        }
    }

    // MARK: - Miniatura

    @ViewBuilder
    private var thumbnailView: some View {
        if let image = thumbnailImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: .controlBackgroundColor))
                Image(systemName: iconForState)
                    .font(.title3)
                    .foregroundStyle(colorForState)
            }
        }
    }

    private func loadThumbnail() async {
        guard job.state == .completed,
              let path = job.localPath else { return }
        let fileURL = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else { return }

        do {
            let image = try await ThumbnailService.shared.generateNSImage(
                for: fileURL,
                targetSize: CGSize(width: 96, height: 128)
            )
            self.thumbnailImage = image
        } catch {
            // Silenciar errores de thumbnailing; se mostrará el icono placeholder
        }
    }

    // MARK: - Menú Contextual

    @ViewBuilder
    private var contextMenuItems: some View {
        if job.state == .downloading || job.state == .queued {
            Button("Cancelar") {
                model.cancel(id: job.id, queue: env.queue)
            }
        }

        if job.state == .failed || job.state == .cancelled {
            Button("Reintentar") {
                model.retry(id: job.id, queue: env.queue)
            }
        }

        if job.state == .completed, job.localPath != nil {
            Button("Abrir") {
                model.openDocument(id: job.id, queue: env.queue)
            }
            Button("Mostrar en Finder") {
                model.openInFinder(id: job.id, queue: env.queue)
            }
            Divider()
            if let sha = job.sha256 {
                Button("Copiar SHA-256") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(sha, forType: .string)
                }
            }
        }
    }

    // MARK: - Formateadores

    private var iconForState: String {
        switch job.state {
        case .received, .parsing: return "doc.badge.clock"
        case .inspecting: return "magnifyingglass"
        case .resolvable: return "checkmark.circle"
        case .queued: return "clock"
        case .downloading: return "arrow.down.circle"
        case .validating: return "shield.checkered"
        case .finalizing: return "gearshape"
        case .completed: return "doc.richtext"
        case .restricted: return "lock.shield"
        case .unsupported: return "xmark.circle"
        case .authenticationRequired: return "person.badge.key"
        case .cancelled: return "xmark"
        case .failed: return "exclamationmark.triangle"
        }
    }

    private var colorForState: Color {
        switch job.state {
        case .received, .parsing, .inspecting, .resolvable, .queued: return .secondary
        case .downloading: return .blue
        case .validating, .finalizing: return .orange
        case .completed: return .green
        case .restricted, .authenticationRequired: return .yellow
        case .unsupported, .cancelled: return .gray
        case .failed: return .red
        }
    }

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
}

// MARK: - Badge de Estado

/// Badge coloreado que muestra el estado actual de un DocumentJob.
public struct StateBadgeView: View {
    let state: DocumentState

    public var body: some View {
        Text(state.description)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch state {
        case .received, .parsing, .resolvable, .queued: return .secondary
        case .inspecting: return .purple
        case .downloading: return .blue
        case .validating, .finalizing: return .orange
        case .completed: return .green
        case .restricted, .authenticationRequired: return .yellow
        case .unsupported, .cancelled: return .gray
        case .failed: return .red
        }
    }
}
