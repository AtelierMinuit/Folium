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
        HStack(alignment: .top, spacing: 16) {
            // Miniatura o icono
            thumbnailView
                .frame(width: 60, height: 80)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

            // Contenido dinámico según el estado
            VStack(alignment: .leading, spacing: 6) {
                
                // Título siempre visible
                Text(job.title ?? "Documento sin título")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                
                // ESTADO 1: RECONOCIDO (.resolvable)
                if job.state == .resolvable {
                    if let author = job.author, !author.isEmpty {
                        Text(author).font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Documento · \(job.mimeType == "application/pdf" ? "PDF" : "Desconocido")")
                        .font(.caption).foregroundStyle(.secondary)
                    if let size = job.fileSize, size > 0 {
                        Text(formatBytes(size))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
                        Button("Descargar") {
                            model.confirmDownload(id: job.id, queue: env.queue)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                }
                
                // ESTADO 2: DESCARGANDO (.queued, .downloading, .validating, etc)
                else if job.state.isActive && job.state != .resolvable {
                    Text(friendlyStateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if job.state == .downloading {
                        ProgressView(value: job.progress)
                            .progressViewStyle(.linear)
                            .tint(.blue)
                        
                        HStack {
                            if job.totalBytes > 0 {
                                Text("\(formatBytes(job.bytesDownloaded)) de \(formatBytes(job.totalBytes))")
                            }
                            Spacer()
                            if job.speedBytesPerSecond > 0 {
                                Text("\(formatSpeed(job.speedBytesPerSecond))")
                            }
                        }
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    } else {
                        // Progress indeterminado para validación, etc.
                        ProgressView()
                            .progressViewStyle(.linear)
                            .scaleEffect(x: 1, y: 0.5, anchor: .center)
                    }
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
                        Button(action: { model.cancel(id: job.id, queue: env.queue) }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // ESTADO 3: COMPLETADO (.completed)
                else if job.state == .completed {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Descarga terminada")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    
                    Text("PDF · \(formatBytes(job.totalBytes))")
                        .font(.caption).foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    HStack {
                        Button("Abrir") {
                            model.openDocument(id: job.id, queue: env.queue)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Mostrar en Finder") {
                            model.openInFinder(id: job.id, queue: env.queue)
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                    }
                }
                
                // ESTADO 4: ERROR (.failed, .cancelled, .restricted, .unsupported, .authenticationRequired)
                else if job.state.isTerminal && job.state != .completed {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(friendlyStateText)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    
                    if let err = job.errorMessage {
                        Text(err)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    HStack {
                        Button("Reintentar") {
                            model.retry(id: job.id, queue: env.queue)
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                    }
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
        // Inspector con click derecho
        .contextMenu {
            contextMenuItems
        }
        .task {
            await loadThumbnail()
            if job.state == .completed {
                await scheduleRefresh()
            }
        }
        .onChange(of: job.state) { oldState, newState in
            if newState == .completed {
                Task {
                    await scheduleRefresh()
                }
            }
        }
    }

    private func scheduleRefresh() async {
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        await MainActor.run {
            model.refreshTrigger.toggle()
        }
    }

    private var friendlyStateText: String {
        switch job.state {
        case .received, .parsing, .inspecting: return "Buscando documento..."
        case .resolvable: return "Reconocido"
        case .queued: return "En cola..."
        case .downloading: return "Descargando..."
        case .validating, .finalizing: return "Verificando..."
        case .completed: return "Terminado"
        case .cancelled: return "Cancelado"
        case .failed: return "Fallo en descarga"
        case .restricted, .authenticationRequired: return "Acceso denegado (Requiere cuenta/pago)"
        case .unsupported: return "No soportado"
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
