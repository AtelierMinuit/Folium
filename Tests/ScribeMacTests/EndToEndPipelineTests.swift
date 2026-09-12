import XCTest
import PDFKit
import SwiftData
@testable import ScribeMacCore

@MainActor
final class EndToEndPipelineTests: XCTestCase {

    nonisolated(unsafe) static var serverProcess: Process?
    nonisolated static let serverPort = 8090
    nonisolated static let baseURLString = "http://127.0.0.1:8090"

    private final class ProgressBox: @unchecked Sendable {
        private let lock = NSLock()
        private var _values: [Double] = []
        var values: [Double] {
            lock.lock(); defer { lock.unlock() }
            return _values
        }
        func append(_ val: Double) {
            lock.lock(); defer { lock.unlock() }
            _values.append(val)
        }
    }

    private var tempRootDir: URL!
    private var store: SwiftDataStore!
    private var downloadManager: DownloadManager!
    private var registry: ProviderRegistry!

    override class func setUp() {
        super.setUp()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["Tests/Fixtures/Server/test_server.py", "\(serverPort)"]
        do {
            try process.run()
            serverProcess = process
            for _ in 0..<20 {
                Thread.sleep(forTimeInterval: 0.1)
                if let healthURL = URL(string: "\(baseURLString)/health"),
                   let data = try? Data(contentsOf: healthURL),
                   let str = String(data: data, encoding: .utf8),
                   str.contains("ok") {
                    break
                }
            }
        } catch {
            print("Error al iniciar servidor en puerto \(serverPort): \(error)")
        }
    }

    override class func tearDown() {
        if let p = serverProcess, p.isRunning {
            p.terminate()
        }
        serverProcess = nil
        super.tearDown()
    }

    override func setUp() async throws {
        tempRootDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ScribeMac_E2E_\(UUID().uuidString)")
        let organizer = FileOrganizer(rootDirectory: tempRootDir)
        downloadManager = DownloadManager(organizer: organizer)
        store = SwiftDataStore(inMemory: true)
        registry = ProviderRegistry.shared
    }

    override func tearDown() async throws {
        if let dir = tempRootDir {
            try? FileManager.default.removeItem(at: dir)
        }
    }

    func testFullEndToEndPipeline() async throws {
        // Step 1: User pastes URL with query params
        let rawURLString = "\(Self.baseURLString)/public/document.pdf?utm_source=twitter&ref=abc"

        // Step 2: Validate & Normalize
        let normalizedURL = try URLNormalizer.normalize(rawURLString)
        XCTAssertEqual(normalizedURL.query, nil)
        XCTAssertEqual(normalizedURL.path, "/public/document.pdf")

        // Step 3: Provider identification
        let provider = try XCTUnwrap(registry.provider(for: normalizedURL))
        XCTAssertEqual(provider.identifier, "direct_pdf")

        // Step 4: Provider inspection
        let inspectResult = try await provider.inspect(normalizedURL)
        XCTAssertEqual(inspectResult.resourceStatus, .downloadable)

        // Step 5: Create DocumentJob
        let initialJob = DocumentJob(
            originalURL: inspectResult.originalURL,
            canonicalURL: inspectResult.canonicalURL,
            provider: inspectResult.providerIdentifier,
            title: "Documento de Prueba E2E",
            author: "Autor E2E",
            resourceStatus: inspectResult.resourceStatus
        )

        // Record initial download attempt in SwiftData
        try store.recordDownload(from: initialJob)

        // Step 6: Resolve download
        let resolution = try await provider.resolveDownload(inspectResult.canonicalURL)

        // Step 7: Download with progress tracking
        let progressBox = ProgressBox()
        let completedJob = try await downloadManager.execute(
            job: initialJob,
            downloadURL: resolution.url,
            suggestedFilename: resolution.suggestedFilename
        ) { progress, _, _ in
            progressBox.append(progress)
        }

        // Step 8: Verify download completion
        XCTAssertEqual(completedJob.downloadStatus, .completed)
        XCTAssertFalse(progressBox.values.isEmpty)
        XCTAssertEqual(progressBox.values.last, 1.0)

        // Step 9: Verify file exists on disk in Library/
        let localPath = try XCTUnwrap(completedJob.localPath)
        let fileURL = URL(fileURLWithPath: localPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertTrue(fileURL.path.contains("/Library/"))

        // Step 10: Verify PDFKit opens the file and reads pages
        let pdfDoc = try XCTUnwrap(PDFDocument(url: fileURL))
        XCTAssertEqual(pdfDoc.pageCount, 1)
        XCTAssertFalse(pdfDoc.isLocked)

        // Step 11: Verify SHA-256 hash was generated
        let computedSHA = try FileHasher.sha256(for: fileURL)
        XCTAssertEqual(completedJob.sha256, computedSHA)
        XCTAssertGreaterThan(completedJob.fileSize ?? 0, 0)

        // Step 12: Save document to SwiftData library
        try store.saveDocument(from: completedJob, pageCount: pdfDoc.pageCount)

        let savedDocs = try store.fetchDocuments()
        XCTAssertEqual(savedDocs.count, 1)
        XCTAssertEqual(savedDocs.first?.title, "Documento de Prueba E2E")
        XCTAssertEqual(savedDocs.first?.sha256, computedSHA)

        // Step 13: Duplicate Detection Verification (re-downloading same content)
        let dupJob = try await downloadManager.execute(
            job: initialJob,
            downloadURL: resolution.url,
            suggestedFilename: resolution.suggestedFilename
        )

        XCTAssertEqual(dupJob.downloadStatus, .completed)
        XCTAssertEqual(dupJob.localPath, localPath, "Duplicate download should resolve to existing file without duplication")
        XCTAssertTrue(dupJob.errorMessage?.contains("copia idéntica") == true)
    }

    func testCancellationPipeline() async throws {
        guard let slowURL = URL(string: "\(Self.baseURLString)/slow") else { return }

        let job = DocumentJob(originalURL: slowURL)

        let task = Task {
            try await downloadManager.execute(job: job, downloadURL: slowURL)
        }

        // Allow download to initiate then cancel
        try await Task.sleep(nanoseconds: 200_000_000)
        await downloadManager.cancel(jobId: job.id)

        let resultJob = try await task.value
        XCTAssertTrue(resultJob.downloadStatus == .cancelled || resultJob.downloadStatus == .failed)

        // Verify incoming temp file is deleted
        let incomingFiles = (try? FileManager.default.contentsOfDirectory(atPath: downloadManager.organizer.incomingDirectory.path)) ?? []
        XCTAssertTrue(incomingFiles.isEmpty, "Incoming temp directory must be cleaned up on cancellation")
    }
}
