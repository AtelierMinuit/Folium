import Foundation

/// Mock provider that enables testing and studying the entire pipeline using local fixtures.
/// Resolves URLs like `scribemac://fixture/document/123` to a sample PDF fixture.
public struct MockRestrictedProvider: DocumentProvider {
    public let identifier = "mock_fixture"
    public let displayName = "Proveedor de Pruebas (Mock / Fixture)"

    private let customFixtureURL: URL?

    public init(customFixtureURL: URL? = nil) {
        self.customFixtureURL = customFixtureURL
    }

    public func canHandle(_ url: URL) -> Bool {
        return (url.scheme?.lowercased() == "scribemac" && (url.host == "fixture" || url.path.hasPrefix("/fixture"))) ||
               url.host == "mock.local"
    }

    public func inspect(_ url: URL) async throws -> ProviderResult {
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        let docId = pathComponents.last ?? "fixture-1"

        let metadata = DocumentMetadata(
            title: "Documento de Muestra (Educativo)",
            author: "Equipo ScribeMac",
            subject: "Prueba de pipeline completo para recursos restringidos simulados",
            pageCount: 2,
            contentType: "application/pdf"
        )

        let resolvedURL = try locateFixtureURL()

        return ProviderResult(
            providerIdentifier: identifier,
            originalURL: url,
            canonicalURL: url,
            resourceStatus: .downloadable,
            metadata: metadata,
            downloadableURL: resolvedURL,
            publicId: docId,
            slug: "muestra-educativa",
            note: "Recurso fixture local activo para desarrollo y validación sin dependencias externas."
        )
    }

    public func resolveDownload(_ url: URL) async throws -> DownloadResult {
        let fixtureFile = try locateFixtureURL()
        return DownloadResult(
            url: fixtureFile,
            suggestedFilename: "ScribeMac-Muestra-Educativa.pdf",
            expectedMIMEType: "application/pdf",
            requiresAuthentication: false
        )
    }

    /// Locates the fixture PDF in bundle, working directory, or creates one if needed.
    public func locateFixtureURL() throws -> URL {
        if let custom = customFixtureURL, FileManager.default.fileExists(atPath: custom.path) {
            return custom
        }

        // Try standard development paths
        let candidates = [
            URL(fileURLWithPath: "Tests/Fixtures/sample-document.pdf"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Tests/Fixtures/sample-document.pdf"),
            URL(fileURLWithPath: "/Users/jorge/Downloads/Github/Dropscribd/Tests/Fixtures/sample-document.pdf")
        ]

        for candidate in candidates {
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        // If not found on disk, write a valid fallback PDF fixture dynamically
        let tempFixture = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ScribeMac-sample-document.pdf")
        if !FileManager.default.fileExists(atPath: tempFixture.path) {
            let minimalValidPDF = Self.createMinimalPDFData()
            try minimalValidPDF.write(to: tempFixture)
        }
        return tempFixture
    }

    /// Generates a valid, readable minimal PDF 1.4 binary data structure
    public static func createMinimalPDFData() -> Data {
        let pdfString = """
        %PDF-1.4
        1 0 obj
        << /Type /Catalog /Pages 2 0 R >>
        endobj
        2 0 obj
        << /Type /Pages /Kids [3 0 R] /Count 1 >>
        endobj
        3 0 obj
        << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>
        endobj
        4 0 obj
        << /Length 55 >>
        stream
        BT
        /F1 24 Tf
        100 700 Td
        (ScribeMac Educational Pipeline Sample) Tj
        ET
        endstream
        endobj
        5 0 obj
        << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
        endobj
        xref
        0 6
        0000000000 65535 f 
        0000000009 00000 n 
        0000000058 00000 n 
        0000000115 00000 n 
        0000000244 00000 n 
        0000000350 00000 n 
        trailer
        << /Size 6 /Root 1 0 R >>
        startxref
        429
        %%EOF
        """
        return pdfString.data(using: .utf8) ?? Data("%PDF-1.4\n%%EOF".utf8)
    }
}
