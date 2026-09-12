import XCTest
@testable import ScribeMacCore

final class PDFValidatorTests: XCTestCase {

    func testValidPDFPassesValidation() throws {
        let validURL = URL(fileURLWithPath: "Tests/Fixtures/sample-document.pdf")
        guard FileManager.default.fileExists(atPath: validURL.path) else {
            XCTFail("Fixture file missing: \(validURL.path)")
            return
        }

        let result = try PDFValidator.validate(at: validURL)
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.pageCount, 1)
        XCTAssertFalse(result.isEncrypted)
        XCTAssertGreaterThan(result.fileSize, 0)
    }

    func testHTMLDisguisedAsPDFIsRejected() throws {
        let htmlURL = URL(fileURLWithPath: "Tests/Fixtures/sample-html-as-pdf.pdf")
        guard FileManager.default.fileExists(atPath: htmlURL.path) else {
            XCTFail("Fixture file missing: \(htmlURL.path)")
            return
        }

        XCTAssertThrowsError(try PDFValidator.validate(at: htmlURL)) { error in
            guard let valError = error as? PDFValidationError else {
                XCTFail("Expected PDFValidationError, got \(error)")
                return
            }
            XCTAssertTrue(valError == .disguisedHTML || valError == .invalidMagicBytes(found: "<!doc") || valError == .invalidMagicBytes(found: "<!DOC"))
        }
    }

    func testCorruptedPDFIsRejected() throws {
        let corruptedURL = URL(fileURLWithPath: "Tests/Fixtures/sample-corrupted.pdf")
        guard FileManager.default.fileExists(atPath: corruptedURL.path) else {
            XCTFail("Fixture file missing: \(corruptedURL.path)")
            return
        }

        XCTAssertThrowsError(try PDFValidator.validate(at: corruptedURL)) { error in
            guard let valError = error as? PDFValidationError else {
                XCTFail("Expected PDFValidationError, got \(error)")
                return
            }
            XCTAssertTrue(valError == .cannotOpenWithPDFKit || valError == .zeroPages)
        }
    }

    func testEmptyFileIsRejected() throws {
        let emptyURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("empty_test.pdf")
        try Data().write(to: emptyURL)
        defer { try? FileManager.default.removeItem(at: emptyURL) }

        XCTAssertThrowsError(try PDFValidator.validate(at: emptyURL)) { error in
            XCTAssertEqual(error as? PDFValidationError, PDFValidationError.emptyFile)
        }
    }
}
