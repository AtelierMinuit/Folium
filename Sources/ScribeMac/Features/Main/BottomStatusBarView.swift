import SwiftUI
import ScribeMacCore
import AppKit

/// Barra de estado inferior de la ventana principal.
/// Muestra transferencias activas, velocidad agregada, volumen descargado y acceso a Finder.
public struct BottomStatusBarView: View {
    @Environment(AppEnvironment.self) private var env
    let model: AppModel

    public var body: some View {
        HStack(spacing: 16) {
            // Conteo de transferencias activas
            let activeCount = model.activeTransferCount(queue: env.queue)
            if activeCount > 0 {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("\(activeCount) \(activeCount == 1 ? "transferencia activa" : "transferencias activas")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Sin transferencias activas")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Velocidad agregada
            let speed = model.activeBytesPerSecond(queue: env.queue)
            if speed > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.down")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                    Text(formatSpeed(speed))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Volumen total descargado
            let totalBytes = model.totalBytesDownloaded(queue: env.queue)
            if totalBytes > 0 {
                Text("Total: \(formatBytes(totalBytes))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Botón para abrir la carpeta de descargas
            Button {
                let libraryURL = env.organizer.libraryDirectory
                if FileManager.default.fileExists(atPath: libraryURL.path) {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: libraryURL.path)
                }
            } label: {
                Image(systemName: "folder")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Abrir carpeta de biblioteca en Finder")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.bar)
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
}
