import SwiftUI
import FoliumCore

public struct HomeView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var viewModel = HomeViewModel()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 28))
                            .foregroundStyle(.tint)
                        Text("Folium")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                    }
                    Text("Analizador arquitectónico de documentos, resolución segura y biblioteca local.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // URL Input Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pega un enlace de documento")
                        .font(.headline)

                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .foregroundStyle(.secondary)

                        TextField("https://... o scribemac://fixture/document/...", text: $viewModel.inputURL)
                            .textFieldStyle(.plain)
                            .font(.system(.body, design: .monospaced))
                            .onSubmit {
                                Task { await viewModel.analyze(environment: env) }
                            }

                        if !viewModel.inputURL.isEmpty {
                            Button {
                                viewModel.inputURL = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            viewModel.pasteFromClipboard()
                        } label: {
                            Label("Pegar", systemImage: "doc.on.clipboard")
                        }
                        .buttonStyle(.bordered)
                        .help("Pegar desde el portapapeles")

                        Button {
                            Task { await viewModel.analyze(environment: env) }
                        } label: {
                            if viewModel.isAnalyzing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Analizar", systemImage: "arrow.right.circle.fill")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.inputURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isAnalyzing)
                    }
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .onDrop(of: [.url, .plainText], isTargeted: nil) { providers in
                        guard let provider = providers.first else { return false }
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in
                            if let url = url {
                                Task { @MainActor in
                                    viewModel.inputURL = url.absoluteString
                                    await viewModel.analyze(environment: env)
                                }
                            }
                        }
                        return true
                    }

                    // Quick samples for educational study
                    HStack(spacing: 8) {
                        Text("Ejemplos:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("Scribd (Restringido)") {
                            viewModel.setScribdSample()
                            Task { await viewModel.analyze(environment: env) }
                        }
                        .buttonStyle(.link)
                        .font(.caption)

                        Text("•").font(.caption).foregroundStyle(.secondary)

                        Button("arXiv (Abierto)") {
                            viewModel.setArXivSample()
                            Task { await viewModel.analyze(environment: env) }
                        }
                        .buttonStyle(.link)
                        .font(.caption)

                        Text("•").font(.caption).foregroundStyle(.secondary)

                        Button("Fixture Local (Mock)") {
                            viewModel.setFixtureSample()
                            Task { await viewModel.analyze(environment: env) }
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                }

                // Error / Status Message
                if let error = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if let status = viewModel.statusMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(status)
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Inspection Result Card
                if let result = viewModel.inspectionResult {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Detalles del Documento")
                                .font(.headline)
                            Spacer()
                            StatusBadgeView(status: result.resourceStatus)
                        }

                        Divider()

                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                            GridRow {
                                Text("Título:")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.secondary)
                                Text(result.metadata.title ?? "Sin título disponible")
                                    .font(.subheadline)
                            }

                            if let author = result.metadata.author, !author.isEmpty {
                                GridRow {
                                    Text("Autor:")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.secondary)
                                    Text(author)
                                        .font(.subheadline)
                                }
                            }

                            GridRow {
                                Text("Fuente:")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.secondary)
                                Text(result.providerIdentifier.capitalized)
                                    .font(.subheadline)
                            }

                            GridRow {
                                Text("URL Canónica:")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.secondary)
                                HStack {
                                    Text(result.canonicalURL.absoluteString)
                                        .font(.system(.caption, design: .monospaced))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Button {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(result.canonicalURL.absoluteString, forType: .string)
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                    }
                                    .buttonStyle(.plain)
                                    .help("Copiar URL canónica")
                                }
                            }

                            if let note = result.note {
                                GridRow {
                                    Text("Diagnóstico:")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.secondary)
                                    Text(note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Divider()

                        // Action Buttons
                        HStack(spacing: 12) {
                            if result.resourceStatus.isActionable {
                                Button {
                                    Task { await viewModel.startDownload(environment: env) }
                                } label: {
                                    if viewModel.isDownloading {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Label("Descargar Documento", systemImage: "arrow.down.doc.fill")
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            } else if result.resourceStatus == .restricted {
                                Button {
                                    viewModel.setFixtureSample()
                                    Task { await viewModel.analyze(environment: env) }
                                } label: {
                                    Label("Probar Pipeline con Fixture Local", systemImage: "play.circle.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .help("Carga un documento local seguro para probar el ciclo completo de descarga y validación")
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                }

                Spacer()
            }
            .padding(24)
        }
    }
}

// MARK: - Status Badge View
public struct StatusBadgeView: View {
    public let status: ResourceStatus

    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(status.description)
                .font(.caption.bold())
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.12))
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch status {
        case .downloadable: return .green
        case .restricted: return .orange
        case .metadataOnly: return .blue
        case .authenticationRequired: return .yellow
        case .unsupported: return .gray
        case .unavailable: return .red
        }
    }
}
