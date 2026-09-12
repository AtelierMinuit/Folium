import SwiftUI
import SwiftData
import ScribeMacCore
import AppKit

public struct LibraryView: View {
    @Environment(AppEnvironment.self) private var env
    @Query(sort: \DocumentRecord.addedAt, order: .reverse) private var documents: [DocumentRecord]

    @State private var searchText = ""
    @State private var selectedDocument: DocumentRecord?

    public init() {}

    private var filteredDocuments: [DocumentRecord] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return documents
        }
        return documents.filter { doc in
            doc.title.localizedCaseInsensitiveContains(searchText) ||
            (doc.author?.localizedCaseInsensitiveContains(searchText) == true) ||
            doc.sha256.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var body: some View {
        HSplitView {
            // Left: List of Documents
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Buscar en biblioteca por título o autor...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                if filteredDocuments.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary.opacity(0.5))
                        Text("No se encontraron documentos.")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Los documentos descargados y validados aparecerán aquí.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredDocuments, selection: $selectedDocument) { doc in
                        DocumentListRowView(doc: doc)
                            .tag(doc)
                            .contextMenu {
                                Button("Abrir en Visor") {
                                    NSWorkspace.shared.open(URL(fileURLWithPath: doc.localPath))
                                }
                                Button("Mostrar en Finder") {
                                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: doc.localPath)])
                                }
                                Button("Copiar Hash SHA-256") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(doc.sha256, forType: .string)
                                }
                                Divider()
                                Button("Eliminar de la Biblioteca", role: .destructive) {
                                    try? env.store.deleteDocument(doc, removeFile: false)
                                    if selectedDocument?.id == doc.id {
                                        selectedDocument = nil
                                    }
                                }
                            }
                    }
                    .listStyle(.inset)
                }
            }
            .frame(minWidth: 320, idealWidth: 380, maxWidth: 500)

            // Right: Detail & PDFKit Preview
            Group {
                if let doc = selectedDocument {
                    DocumentDetailPreviewView(doc: doc)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.viewfinder")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary.opacity(0.4))
                        Text("Selecciona un documento para previsualizarlo.")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 400)
        }
    }
}

// MARK: - Row View
struct DocumentListRowView: View {
    let doc: DocumentRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(doc.title)
                .font(.headline)
                .lineLimit(1)
            if let author = doc.author, !author.isEmpty {
                Text(author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                Label("\(doc.pageCount) pág.", systemImage: "doc")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Label(formatBytes(doc.fileSize), systemImage: "internaldrive")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(doc.providerName.capitalized)
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
        .padding(.vertical, 4)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Detail Preview View
struct DocumentDetailPreviewView: View {
    @Environment(AppEnvironment.self) private var env
    let doc: DocumentRecord

    var body: some View {
        let fileURL = URL(fileURLWithPath: doc.localPath)
        let exists = FileManager.default.fileExists(atPath: doc.localPath)

        VStack(alignment: .leading, spacing: 12) {
            // Document action bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(doc.title)
                        .font(.title3.bold())
                    if let author = doc.author {
                        Text(author)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()

                Button("Abrir") {
                    NSWorkspace.shared.open(fileURL)
                }
                .buttonStyle(.bordered)
                .disabled(!exists)

                Button("Mostrar en Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                }
                .buttonStyle(.bordered)
                .disabled(!exists)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Technical metadata badges
            HStack(spacing: 12) {
                Label("Páginas: \(doc.pageCount)", systemImage: "doc.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("Tamaño: \(formatBytes(doc.fileSize))", systemImage: "scalemass.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("Hash: \(doc.sha256.prefix(12))...", systemImage: "number")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help(doc.sha256)
            }
            .padding(.horizontal, 16)

            Divider()

            // PDFKit embedded reader
            if exists {
                PDFPreviewView(url: fileURL)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.red)
                    Text("El archivo físico no se encuentra en la ruta: \(doc.localPath)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
