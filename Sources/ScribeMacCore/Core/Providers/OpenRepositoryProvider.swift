import Foundation

/// Provider for open access academic and public repositories (e.g. arXiv.org).
/// Resolves public open-access preprint identifiers directly to their public PDF downloads.
public struct OpenRepositoryProvider: DocumentProvider {
    public let identifier = "open_repository"
    public let displayName = "Repositorio Abierto (arXiv)"

    public init() {}

    public func canHandle(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "arxiv.org" || host.hasSuffix(".arxiv.org")
    }

    public func inspect(_ url: URL) async throws -> ProviderResult {
        let path = url.path
        // Match /abs/{id} or /pdf/{id}
        let pattern = #"^/(?:abs|pdf)/([0-9]+\.[0-9]+(?:v[0-9]+)?)(?:\.pdf)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            throw ProviderError.unhandledURL(url)
        }

        let range = NSRange(path.startIndex..<path.endIndex, in: path)
        guard let match = regex.firstMatch(in: path, options: [], range: range),
              let idRange = Range(match.range(at: 1), in: path) else {
            return ProviderResult(
                providerIdentifier: identifier,
                originalURL: url,
                canonicalURL: url,
                resourceStatus: .unsupported,
                note: "Formato de arXiv no reconocido."
            )
        }

        let paperId = String(path[idRange])
        guard let pdfURL = URL(string: "https://arxiv.org/pdf/\(paperId).pdf"),
              let canonicalURL = URL(string: "https://arxiv.org/abs/\(paperId)") else {
            throw ProviderError.unhandledURL(url)
        }

        let metadata = DocumentMetadata(
            title: "arXiv Paper \(paperId)",
            subject: "Artículo de investigación de acceso abierto (arXiv.org)",
            contentType: "application/pdf"
        )

        return ProviderResult(
            providerIdentifier: identifier,
            originalURL: url,
            canonicalURL: canonicalURL,
            resourceStatus: .downloadable,
            metadata: metadata,
            downloadableURL: pdfURL,
            publicId: paperId,
            slug: "arxiv-\(paperId)",
            note: "Repositorio abierto con descarga pública disponible."
        )
    }

    public func resolveDownload(_ url: URL) async throws -> DownloadResult {
        let inspection = try await inspect(url)
        guard let downloadURL = inspection.downloadableURL else {
            throw ProviderError.resourceNotFound(url)
        }
        return DownloadResult(
            url: downloadURL,
            suggestedFilename: "arXiv-\(inspection.publicId ?? "paper").pdf",
            expectedMIMEType: "application/pdf",
            requiresAuthentication: false
        )
    }
}
