import XCTest
@testable import FoliumCore

final class DownloadTests: XCTestCase {

    nonisolated(unsafe) static var serverProcess: Process?
    static let serverPort = 8089
    static let baseURLString = "http://127.0.0.1:\(serverPort)"

    private var tempRootDir: URL!
    private var downloadManager: DownloadManager!

    override class func setUp() {
        super.setUp()
        // Launch test fixture server
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["Tests/Fixtures/Server/test_server.py", "\(serverPort)"]

        do {
            try process.run()
            serverProcess = process
            // Wait for server to start
            var isReady = false
            for _ in 0..<20 {
                Thread.sleep(forTimeInterval: 0.1)
                if let healthURL = URL(string: "\(baseURLString)/health"),
                   let data = try? Data(contentsOf: healthURL),
                   let str = String(data: data, encoding: .utf8),
                   str.contains("ok") {
                    isReady = true
                    break
                }
            }
            if !isReady {
                print("Aviso: El servidor de prueba no respondió en el puerto \(serverPort)")
            }
        } catch {
            print("No se pudo iniciar el servidor de prueba: \(error)")
        }
    }

    override class func tearDown() {
        if let process = serverProcess, process.isRunning {
            process.terminate()
        }
        serverProcess = nil
        super.tearDown()
    }

    override func setUpWithError() throws {
        tempRootDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Folium_DownloadTest_\(UUID().uuidString)")
        let organizer = FileOrganizer(rootDirectory: tempRootDir)
        downloadManager = DownloadManager(organizer: organizer)
    }

    override func tearDownWithError() throws {
        if let dir = tempRootDir {
            try? FileManager.default.removeItem(at: dir)
        }
    }

    func testDownloadPublicPDFSucceedsAndValidates() async throws {
        guard let url = URL(string: "\(Self.baseURLString)/public/document.pdf") else { return }

        let job = DocumentJob(originalURL: url)
        let completedJob = try await downloadManager.execute(job: job, downloadURL: url, suggestedFilename: "documento-publico.pdf")

        XCTAssertEqual(completedJob.downloadStatus, .completed)
        XCTAssertNotNil(completedJob.localPath)
        XCTAssertNotNil(completedJob.sha256)
        XCTAssertGreaterThan(completedJob.fileSize ?? 0, 0)
        XCTAssertEqual(completedJob.mimeType, "application/pdf")

        if let path = completedJob.localPath {
            XCTAssertTrue(FileManager.default.fileExists(atPath: path))
            let validation = try PDFValidator.validate(at: URL(fileURLWithPath: path))
            XCTAssertTrue(validation.isValid)
        }
    }

    func testDownloadRedirectFollowsToTarget() async throws {
        guard let url = URL(string: "\(Self.baseURLString)/redirect/document") else { return }

        let job = DocumentJob(originalURL: url)
        let completedJob = try await downloadManager.execute(job: job, downloadURL: url)

        XCTAssertEqual(completedJob.downloadStatus, .completed)
        XCTAssertNotNil(completedJob.localPath)
        XCTAssertNotNil(completedJob.sha256)
    }

    func testDownloadDisguisedHTMLIsRejectedAndMovedToFailed() async throws {
        guard let url = URL(string: "\(Self.baseURLString)/html-as-pdf") else { return }

        let job = DocumentJob(originalURL: url)
        let failedJob = try await downloadManager.execute(job: job, downloadURL: url, suggestedFilename: "fake.pdf")

        XCTAssertEqual(failedJob.downloadStatus, .failed)
        XCTAssertTrue(failedJob.errorMessage?.contains("Validación PDF fallida") == true || failedJob.errorMessage?.contains("Tipo MIME no esperado") == true)

        let failedFiles = (try? FileManager.default.contentsOfDirectory(atPath: downloadManager.organizer.failedDirectory.path)) ?? []
        XCTAssertFalse(failedFiles.isEmpty, "El archivo que falló la validación debe moverse a la carpeta Failed/")
    }

    func testDownloadNotFoundReturnsError() async throws {
        guard let url = URL(string: "\(Self.baseURLString)/not-found") else { return }

        let job = DocumentJob(originalURL: url)
        let failedJob = try await downloadManager.execute(job: job, downloadURL: url)

        XCTAssertEqual(failedJob.downloadStatus, .failed)
        XCTAssertTrue(failedJob.errorMessage?.contains("404") == true)
    }

    func testDownloadFixtureProtocolSucceedsLocally() async throws {
        let fixtureProvider = MockRestrictedProvider()
        let fixtureURL = try XCTUnwrap(URL(string: "scribemac://fixture/document/sample-test"))

        let resolution = try await fixtureProvider.resolveDownload(fixtureURL)
        let job = DocumentJob(originalURL: fixtureURL)

        let completedJob = try await downloadManager.execute(
            job: job,
            downloadURL: resolution.url,
            suggestedFilename: resolution.suggestedFilename
        )

        XCTAssertEqual(completedJob.downloadStatus, .completed)
        XCTAssertNotNil(completedJob.localPath)
        XCTAssertNotNil(completedJob.sha256)
        if let path = completedJob.localPath {
            XCTAssertTrue(FileManager.default.fileExists(atPath: path))
        }
    }
}
