import SwiftUI
import FoliumCore
import AppKit

public struct DownloadsView: View {
    @Environment(AppEnvironment.self) private var env

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cola de Descargas e Historial")
                        .font(.title2.bold())
                    Text("Supervisa las transferencias activas, estado de validación y procedencia.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            Divider()

            if env.queue.jobs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("No hay descargas activas ni recientes.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Pega un enlace en la pestaña Inicio para descargar un documento.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(env.queue.jobs) { job in
                    DownloadJobRowView(job: job)
                        .padding(.vertical, 6)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }
}

// MARK: - Download Job Row
struct DownloadJobRowView: View {
    @Environment(AppEnvironment.self) private var env
    let job: DocumentJob

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.title ?? "Documento sin título")
                        .font(.headline)
                        .lineLimit(1)
                    if let author = job.author, !author.isEmpty {
                        Text("Autor: \(author)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                DownloadStatusBadgeView(status: job.downloadStatus)
            }

            // Progress bar
            if job.downloadStatus == .downloading || job.downloadStatus == .validating || job.downloadStatus == .queued {
                ProgressView(value: job.progress)
                    .progressViewStyle(.linear)

                HStack {
                    if job.totalBytes > 0 {
                        Text("\(formatBytes(job.bytesDownloaded)) de \(formatBytes(job.totalBytes)) (\(Int(job.progress * 100))%)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if job.bytesDownloaded > 0 {
                        Text("\(formatBytes(job.bytesDownloaded)) descargados")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if job.downloadStatus == .validating {
                        Text("Comprobando bytes mágicos y PDFKit...")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
            }

            // Error message if any
            if let error = job.errorMessage, job.downloadStatus == .failed {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Metadata row for completed jobs
            if job.downloadStatus == .completed {
                HStack(spacing: 12) {
                    if let size = job.fileSize {
                        Label(formatBytes(size), systemImage: "internaldrive")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let sha = job.sha256 {
                        Label("SHA-256: \(sha.prefix(12))...", systemImage: "checkmark.shield")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .help("Hash completo: \(sha)")
                    }
                }
            }

            // Action Buttons
            HStack(spacing: 8) {
                if job.downloadStatus == .downloading || job.downloadStatus == .queued {
                    Button("Cancelar") {
                        env.queue.cancel(jobId: job.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else if job.downloadStatus == .failed || job.downloadStatus == .cancelled {
                    Button("Reintentar") {
                        env.queue.retry(jobId: job.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if job.downloadStatus == .completed, let path = job.localPath {
                    let fileURL = URL(fileURLWithPath: path)

                    Button("Abrir") {
                        NSWorkspace.shared.open(fileURL)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Mostrar en Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if let sha = job.sha256 {
                        Button("Copiar SHA-256") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(sha, forType: .string)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .help("Copiar hash criptográfico al portapapeles")
                    }
                }

                Spacer()
            }
        }
        .padding(8)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Download Status Badge
struct DownloadStatusBadgeView: View {
    let status: DownloadStatus

    var body: some View {
        Text(status.description)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch status {
        case .idle, .queued: return .secondary
        case .inspecting: return .purple
        case .downloading: return .blue
        case .validating: return .orange
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }
}
