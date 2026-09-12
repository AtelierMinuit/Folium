import SwiftUI
import SwiftData
import FoliumCore
import AppKit

public struct LibraryView: View {
    @Environment(AppEnvironment.self) private var env
    @Query(sort: \DocumentRecord.addedAt, order: .reverse) private var documents: [DocumentRecord]

    @State private var searchText = ""
    @AppStorage("libraryViewMode") private var viewMode: ViewMode = .grid

    enum ViewMode: String {
        case grid = "Portadas"
        case list = "Lista"
    }

    private let onlyFavorites: Bool

    public init(onlyFavorites: Bool = false) {
        self.onlyFavorites = onlyFavorites
    }

    private var filteredDocuments: [DocumentRecord] {
        var docs = documents
        if onlyFavorites {
            docs = docs.filter { $0.isFavorite }
        }
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return docs
        }
        return docs.filter { doc in
            doc.title.localizedCaseInsensitiveContains(searchText) ||
            (doc.author?.localizedCaseInsensitiveContains(searchText) == true) ||
            doc.sha256.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Toolbar customizada
            HStack {
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Buscar en biblioteca...", text: $searchText)
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
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
                .frame(width: 250)

                Spacer()

                Picker("Modo de vista", selection: $viewMode) {
                    Label("Portadas", systemImage: "square.grid.2x2").tag(ViewMode.grid)
                    Label("Lista", systemImage: "list.bullet").tag(ViewMode.list)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            .padding(12)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            if filteredDocuments.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: onlyFavorites ? "star.slash" : "books.vertical")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text(onlyFavorites ? "No tienes favoritos guardados" : "Tu biblioteca está vacía")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(onlyFavorites ? "Marca documentos con una estrella en su menú contextual para verlos aquí." : "Pega un enlace o descarga un documento para comenzar a construir tu biblioteca.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    if viewMode == .grid {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 20)], spacing: 20) {
                            ForEach(filteredDocuments) { doc in
                                LibraryGridCardView(doc: doc)
                            }
                        }
                        .padding(20)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredDocuments) { doc in
                                DocumentListRowView(doc: doc)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                }
            }
        }
        .navigationTitle(onlyFavorites ? "Favoritos" : "Biblioteca")
    }
}

// MARK: - Grid Card View
struct LibraryGridCardView: View {
    let doc: DocumentRecord
    @State private var thumbnail: NSImage?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .aspectRatio(0.7, contentMode: .fit)
                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
                
                if let image = thumbnail {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "doc.richtext")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                }

                if doc.isFavorite {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                                .padding(6)
                                .background(.black.opacity(0.4), in: Circle())
                                .padding(6)
                        }
                        Spacer()
                    }
                }
            }
            .contextMenu {
                contextMenuContent
            }
            .onTapGesture(count: 2) {
                openDocument()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(doc.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                if let author = doc.author {
                    Text(author)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 2)
        }
        .task {
            if FileManager.default.fileExists(atPath: doc.localPath) {
                if let img = try? await ThumbnailService.shared.generateNSImage(for: URL(fileURLWithPath: doc.localPath), targetSize: CGSize(width: 140, height: 200)) {
                    thumbnail = img
                }
            }
        }
    }
    
    @ViewBuilder
    private var contextMenuContent: some View {
        Button("Abrir") { openDocument() }
        Button("Mostrar en Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: doc.localPath)])
        }
        Divider()
        Button(doc.isFavorite ? "Quitar de Favoritos" : "Marcar como Favorito") {
            doc.isFavorite.toggle()
        }
        Divider()
        Button("Copiar SHA-256") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(doc.sha256, forType: .string)
        }
    }
    
    private func openDocument() {
        NSWorkspace.shared.open(URL(fileURLWithPath: doc.localPath))
    }
}

// MARK: - Row View
struct DocumentListRowView: View {
    let doc: DocumentRecord

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "doc.fill")
                .font(.title2)
                .foregroundStyle(.blue.opacity(0.8))
                
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
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatBytes(doc.fileSize))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(doc.addedAt, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            if doc.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }

            Button("Abrir") {
                NSWorkspace.shared.open(URL(fileURLWithPath: doc.localPath))
            }
            .buttonStyle(.bordered)
        }
        .contextMenu {
            Button("Mostrar en Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: doc.localPath)])
            }
            Divider()
            Button(doc.isFavorite ? "Quitar de Favoritos" : "Marcar como Favorito") {
                doc.isFavorite.toggle()
            }
            Divider()
            Button("Copiar SHA-256") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(doc.sha256, forType: .string)
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
