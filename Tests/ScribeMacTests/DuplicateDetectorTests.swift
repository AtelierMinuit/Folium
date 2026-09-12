import XCTest
@testable import ScribeMacCore

final class DuplicateDetectorTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ScribeMac_DupTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let dir = tempDir {
            try? FileManager.default.removeItem(at: dir)
        }
    }

    func testUniqueFileGoesToDesiredDestination() throws {
        let desiredName = "Mi Documento.pdf"
        let resolution = try DuplicateDetector.resolveDestination(
            desiredFilename: desiredName,
            sourceFileSize: 1024,
            sourceSHA256: "aabbccdd",
            destinationDirectory: tempDir
        )

        guard case .uniqueDestination(let targetURL) = resolution else {
            XCTFail("Expected uniqueDestination")
            return
        }

        XCTAssertEqual(targetURL.lastPathComponent, "Mi Documento.pdf")
    }

    func testExactDuplicateDetectionSameNameAndSameHash() throws {
        let desiredName = "Documento Existente.pdf"
        let fileURL = tempDir.appendingPathComponent("Documento Existente.pdf")
        let content = "PDF-Content-Exact".data(using: .utf8)!
        try content.write(to: fileURL)

        let hash = FileHasher.sha256(for: content)
        let size = Int64(content.count)

        let resolution = try DuplicateDetector.resolveDestination(
            desiredFilename: desiredName,
            sourceFileSize: size,
            sourceSHA256: hash,
            destinationDirectory: tempDir
        )

        guard case .exactDuplicate(let existingURL) = resolution else {
            XCTFail("Expected exactDuplicate resolution")
            return
        }

        XCTAssertEqual(existingURL.path, fileURL.path)
    }

    func testSameNameDifferentHashProducesNumberedVariant() throws {
        let desiredName = "Reporte.pdf"
        let fileURL = tempDir.appendingPathComponent("Reporte.pdf")
        let existingContent = "Original File 1".data(using: .utf8)!
        try existingContent.write(to: fileURL)

        let newContent = "Modified File 2 Different".data(using: .utf8)!
        let newHash = FileHasher.sha256(for: newContent)
        let newSize = Int64(newContent.count)

        let resolution = try DuplicateDetector.resolveDestination(
            desiredFilename: desiredName,
            sourceFileSize: newSize,
            sourceSHA256: newHash,
            destinationDirectory: tempDir
        )

        guard case .uniqueDestination(let targetURL) = resolution else {
            XCTFail("Expected uniqueDestination with incremented counter")
            return
        }

        XCTAssertEqual(targetURL.lastPathComponent, "Reporte (2).pdf")
    }

    func testMultipleVersionsIncrementSequentially() throws {
        let content1 = "File 1".data(using: .utf8)!
        let content2 = "File 2".data(using: .utf8)!
        let content3 = "File 3".data(using: .utf8)!

        try content1.write(to: tempDir.appendingPathComponent("Tesis.pdf"))
        try content2.write(to: tempDir.appendingPathComponent("Tesis (2).pdf"))

        let newHash = FileHasher.sha256(for: content3)
        let resolution = try DuplicateDetector.resolveDestination(
            desiredFilename: "Tesis.pdf",
            sourceFileSize: Int64(content3.count),
            sourceSHA256: newHash,
            destinationDirectory: tempDir
        )

        guard case .uniqueDestination(let targetURL) = resolution else {
            XCTFail("Expected uniqueDestination")
            return
        }

        XCTAssertEqual(targetURL.lastPathComponent, "Tesis (3).pdf")
    }
}
