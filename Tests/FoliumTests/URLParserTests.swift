import XCTest
@testable import FoliumCore

final class URLParserTests: XCTestCase {

    // MARK: - Normalizer Tests
    func testNormalizerStripsTrackingParameters() throws {
        let dirty = "https://www.example.com/doc.pdf?utm_source=twitter&utm_medium=social&ref=share_btn&page=2"
        let normalized = try URLNormalizer.normalize(dirty)

        XCTAssertEqual(normalized.host, "www.example.com")
        XCTAssertEqual(normalized.path, "/doc.pdf")
        XCTAssertTrue(normalized.query?.contains("page=2") == true)
        XCTAssertFalse(normalized.query?.contains("utm_source") == true)
        XCTAssertFalse(normalized.query?.contains("ref=") == true)
    }

    func testNormalizerRejectsUnsupportedSchemes() {
        XCTAssertThrowsError(try URLNormalizer.normalize("ftp://example.com/file.pdf")) { error in
            guard case URLErrorReason.unsupportedScheme(let scheme) = error else {
                XCTFail("Expected unsupportedScheme error, got \(error)")
                return
            }
            XCTAssertEqual(scheme, "ftp")
        }

        XCTAssertThrowsError(try URLNormalizer.normalize("javascript:alert(1)"))
        XCTAssertThrowsError(try URLNormalizer.normalize("data:application/pdf;base64,123"))
    }

    func testNormalizerRejectsPathTraversal() {
        XCTAssertThrowsError(try URLNormalizer.normalize("https://example.com/../../etc/passwd")) { error in
            XCTAssertEqual(error as? URLErrorReason, URLErrorReason.pathTraversalDetected)
        }
        XCTAssertThrowsError(try URLNormalizer.normalize("https://example.com/%2e%2e/secret.pdf")) { error in
            XCTAssertEqual(error as? URLErrorReason, URLErrorReason.pathTraversalDetected)
        }
    }

    // MARK: - Scribd Parser Tests
    func testScribdValidDocumentWithSlug() throws {
        let url = try XCTUnwrap(URL(string: "https://www.scribd.com/document/123456789/trabajo-social"))
        let info = ScribdURLParser.parse(url)

        XCTAssertNotNil(info)
        XCTAssertEqual(info?.id, "123456789")
        XCTAssertEqual(info?.slug, "trabajo-social")
        XCTAssertEqual(info?.resourceType, "document")
        XCTAssertEqual(info?.canonicalURL.absoluteString, "https://www.scribd.com/document/123456789/trabajo-social")
    }

    func testScribdDocAlias() throws {
        let url = try XCTUnwrap(URL(string: "https://scribd.com/doc/987654321/tesis-doctoral"))
        let info = ScribdURLParser.parse(url)

        XCTAssertNotNil(info)
        XCTAssertEqual(info?.id, "987654321")
        XCTAssertEqual(info?.slug, "tesis-doctoral")
        XCTAssertEqual(info?.resourceType, "document")
        XCTAssertEqual(info?.canonicalURL.absoluteString, "https://www.scribd.com/document/987654321/tesis-doctoral")
    }

    func testScribdPresentationType() throws {
        let url = try XCTUnwrap(URL(string: "https://es.scribd.com/presentation/555444333/slides-conferencia"))
        let info = ScribdURLParser.parse(url)

        XCTAssertNotNil(info)
        XCTAssertEqual(info?.id, "555444333")
        XCTAssertEqual(info?.slug, "slides-conferencia")
        XCTAssertEqual(info?.resourceType, "presentation")
        XCTAssertEqual(info?.canonicalURL.absoluteString, "https://www.scribd.com/presentation/555444333/slides-conferencia")
    }

    func testScribdWithoutSlug() throws {
        let url = try XCTUnwrap(URL(string: "https://www.scribd.com/document/424242/"))
        let info = ScribdURLParser.parse(url)

        XCTAssertNotNil(info)
        XCTAssertEqual(info?.id, "424242")
        XCTAssertNil(info?.slug)
        XCTAssertEqual(info?.canonicalURL.absoluteString, "https://www.scribd.com/document/424242")
    }

    func testScribdInvalidDomain() throws {
        let url = try XCTUnwrap(URL(string: "https://www.not-scribd.com/document/123/sample"))
        let info = ScribdURLParser.parse(url)
        XCTAssertNil(info)
    }

    func testClassifier() throws {
        let scribdURL = try XCTUnwrap(URL(string: "https://www.scribd.com/document/123/sample"))
        XCTAssertEqual(URLClassifier.classify(scribdURL), .scribd)

        let directURL = try XCTUnwrap(URL(string: "https://example.com/reports/annual-2024.pdf"))
        XCTAssertEqual(URLClassifier.classify(directURL), .directPDF)

        let arxivURL = try XCTUnwrap(URL(string: "https://arxiv.org/abs/2301.00001"))
        XCTAssertEqual(URLClassifier.classify(arxivURL), .openRepository)

        let fixtureURL = try XCTUnwrap(URL(string: "scribemac://fixture/document/sample-1"))
        XCTAssertEqual(URLClassifier.classify(fixtureURL), .fixture)
    }
}
