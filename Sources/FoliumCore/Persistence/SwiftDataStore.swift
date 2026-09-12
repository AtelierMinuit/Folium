import Foundation
import SwiftData

@MainActor
public final class SwiftDataStore {
    public static let shared = SwiftDataStore()

    public let container: ModelContainer

    public var context: ModelContext {
        container.mainContext
    }

    public init(inMemory: Bool = false) {
        do {
            let schema = Schema([
                DocumentRecord.self,
                DownloadRecord.self,
                ProviderRecord.self
            ])
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: inMemory
            )
            self.container = try ModelContainer(for: schema, configurations: [configuration])
            AppLogger.database.info("SwiftData ModelContainer inicializado correctamente (inMemory: \(inMemory)).")
        } catch {
            fatalError("Error crítico al inicializar SwiftData ModelContainer: \(error.localizedDescription)")
        }
    }

    /// Records or updates a downloaded document in the persistent local library.
    public func saveDocument(from job: DocumentJob, pageCount: Int = 1) throws {
        guard let localPath = job.localPath,
              let sha256 = job.sha256,
              let fileSize = job.fileSize else {
            return
        }

        // Check if document already exists by SHA-256
        let descriptor = FetchDescriptor<DocumentRecord>(
            predicate: #Predicate { $0.sha256 == sha256 }
        )

        let existing = try context.fetch(descriptor)
        if let doc = existing.first {
            doc.localPath = localPath
            doc.title = job.title ?? doc.title
            doc.author = job.author ?? doc.author
            doc.pageCount = pageCount
        } else {
            let newDoc = DocumentRecord(
                id: job.id,
                title: job.title ?? "Documento",
                author: job.author,
                sha256: sha256,
                fileSize: fileSize,
                localPath: localPath,
                mimeType: job.mimeType ?? "application/pdf",
                canonicalURL: job.canonicalURL?.absoluteString,
                providerName: job.provider ?? "Desconocido",
                pageCount: pageCount,
                createdAt: job.createdAt,
                addedAt: Date()
            )
            context.insert(newDoc)
        }

        try context.save()
    }

    /// Logs an entry in the download audit history.
    public func recordDownload(from job: DocumentJob) throws {
        let record = DownloadRecord(
            id: job.id,
            originalURL: job.originalURL.absoluteString,
            canonicalURL: job.canonicalURL?.absoluteString,
            provider: job.provider ?? "Desconocido",
            title: job.title,
            author: job.author,
            resourceStatus: job.resourceStatus.rawValue,
            downloadStatus: job.downloadStatus.rawValue,
            createdAt: job.createdAt,
            completedAt: job.completedAt,
            localPath: job.localPath,
            mimeType: job.mimeType,
            fileSize: job.fileSize,
            sha256: job.sha256,
            errorMessage: job.errorMessage
        )
        context.insert(record)
        try context.save()
    }

    /// Fetches all documents in the library, sorted by addition date descending.
    public func fetchDocuments(searchQuery: String? = nil) throws -> [DocumentRecord] {
        var descriptor = FetchDescriptor<DocumentRecord>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        if let query = searchQuery, !query.isEmpty {
            descriptor.predicate = #Predicate { doc in
                doc.title.localizedStandardContains(query)
            }
        }
        return try context.fetch(descriptor)
    }

    /// Fetches all download audit records, sorted by creation date descending.
    public func fetchDownloads() throws -> [DownloadRecord] {
        let descriptor = FetchDescriptor<DownloadRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Deletes a document record and optionally deletes the physical file.
    public func deleteDocument(_ document: DocumentRecord, removeFile: Bool = false) throws {
        if removeFile {
            try? FileManager.default.removeItem(atPath: document.localPath)
        }
        context.delete(document)
        try context.save()
    }

    /// Clears download history.
    public func clearDownloads() throws {
        try context.delete(model: DownloadRecord.self)
        try context.save()
    }
}
