import XCTest
import SwiftData
@testable import FoliumCore

@MainActor
final class SwiftDataStoreTests: XCTestCase {

    private var store: SwiftDataStore!

    override func setUp() async throws {
        store = SwiftDataStore(inMemory: true)
    }

    func testSaveAndFetchDocument() throws {
        var job = DocumentJob(originalURL: URL(string: "https://example.com/doc.pdf")!)
        job.localPath = "/tmp/test.pdf"
        job.title = "Documento de Prueba"
        job.author = "Investigador"
        job.sha256 = "1234567890abcdef"
        job.fileSize = 2048
        job.provider = "direct_pdf"

        try store.saveDocument(from: job, pageCount: 5)

        let docs = try store.fetchDocuments()
        XCTAssertEqual(docs.count, 1)
        XCTAssertEqual(docs.first?.title, "Documento de Prueba")
        XCTAssertEqual(docs.first?.author, "Investigador")
        XCTAssertEqual(docs.first?.sha256, "1234567890abcdef")
        XCTAssertEqual(docs.first?.pageCount, 5)
    }

    func testRecordDownloadHistory() throws {
        let job = DocumentJob(
            originalURL: URL(string: "https://example.com/file.pdf")!,
            provider: "direct_pdf",
            title: "Auditoría de Descarga",
            resourceStatus: .downloadable,
            downloadStatus: .completed
        )

        try store.recordDownload(from: job)

        let history = try store.fetchDownloads()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.title, "Auditoría de Descarga")
        XCTAssertEqual(history.first?.downloadStatus, DownloadStatus.completed.rawValue)
    }
}
