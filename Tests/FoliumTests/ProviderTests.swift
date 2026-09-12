import XCTest
@testable import FoliumCore

final class ProviderTests: XCTestCase {

    func testScribdMetadataProviderCanHandleAndClassifiesRestricted() async throws {
        let provider = ScribdMetadataProvider()
        let url = try XCTUnwrap(URL(string: "https://www.scribd.com/document/123456789/trabajo-social"))

        XCTAssertTrue(provider.canHandle(url))

        let result = try await provider.inspect(url)
        XCTAssertEqual(result.providerIdentifier, "scribd")
        XCTAssertEqual(result.publicId, "123456789")
        XCTAssertEqual(result.slug, "trabajo-social")
        XCTAssertEqual(result.resourceStatus, .restricted)
        XCTAssertNil(result.downloadableURL)

        // Attempting to resolve download should throw restrictedResource
        do {
            _ = try await provider.resolveDownload(url)
            XCTFail("Should not allow unauthorized download of restricted document")
        } catch let error as ProviderError {
            guard case .restrictedResource = error else {
                XCTFail("Expected restrictedResource error, got \(error)")
                return
            }
        }
    }

    func testMockRestrictedProviderResolvesFixture() async throws {
        let provider = MockRestrictedProvider()
        let url = try XCTUnwrap(URL(string: "scribemac://fixture/document/123"))

        XCTAssertTrue(provider.canHandle(url))

        let inspectResult = try await provider.inspect(url)
        XCTAssertEqual(inspectResult.resourceStatus, .downloadable)
        XCTAssertNotNil(inspectResult.downloadableURL)

        let downloadResult = try await provider.resolveDownload(url)
        XCTAssertEqual(downloadResult.expectedMIMEType, "application/pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: downloadResult.url.path))
    }

    func testOpenRepositoryProviderResolvesArXiv() async throws {
        let provider = OpenRepositoryProvider()
        let url = try XCTUnwrap(URL(string: "https://arxiv.org/abs/2301.00001"))

        XCTAssertTrue(provider.canHandle(url))

        let inspectResult = try await provider.inspect(url)
        XCTAssertEqual(inspectResult.providerIdentifier, "open_repository")
        XCTAssertEqual(inspectResult.resourceStatus, .downloadable)
        XCTAssertEqual(inspectResult.publicId, "2301.00001")
        XCTAssertEqual(inspectResult.downloadableURL?.absoluteString, "https://arxiv.org/pdf/2301.00001.pdf")

        let downloadResult = try await provider.resolveDownload(url)
        XCTAssertEqual(downloadResult.url.absoluteString, "https://arxiv.org/pdf/2301.00001.pdf")
    }

    func testDirectPDFProviderCanHandle() throws {
        let provider = DirectPDFProvider()
        let pdfURL = try XCTUnwrap(URL(string: "https://example.com/reports/document.pdf"))
        XCTAssertTrue(provider.canHandle(pdfURL))

        let nonPdfURL = try XCTUnwrap(URL(string: "https://example.com/reports/index.html"))
        XCTAssertFalse(provider.canHandle(nonPdfURL))

        let scribdURL = try XCTUnwrap(URL(string: "https://www.scribd.com/document/123.pdf"))
        XCTAssertFalse(provider.canHandle(scribdURL))
    }

    func testProviderRegistryResolution() throws {
        let registry = ProviderRegistry.shared

        let fixtureURL = try XCTUnwrap(URL(string: "scribemac://fixture/document/test"))
        XCTAssertEqual(registry.provider(for: fixtureURL)?.identifier, "mock_fixture")

        let scribdURL = try XCTUnwrap(URL(string: "https://www.scribd.com/document/123/sample"))
        XCTAssertEqual(registry.provider(for: scribdURL)?.identifier, "scribd")

        let arxivURL = try XCTUnwrap(URL(string: "https://arxiv.org/abs/2105.12345"))
        XCTAssertEqual(registry.provider(for: arxivURL)?.identifier, "open_repository")

        let directURL = try XCTUnwrap(URL(string: "https://example.com/doc.pdf"))
        XCTAssertEqual(registry.provider(for: directURL)?.identifier, "direct_pdf")
    }
}
