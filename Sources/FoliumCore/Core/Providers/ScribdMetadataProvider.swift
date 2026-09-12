import Foundation

/// Educational provider for analyzing public Scribd documents.
/// Strict compliance: does not bypass paywalls, DRM, CAPTCHAs, or authentication.
/// If no public authorized download is available, classifies as .restricted.
public struct ScribdMetadataProvider: DocumentProvider {
    public let identifier = "scribd"
    public let displayName = "Scribd (Analizador Educativo)"

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func canHandle(_ url: URL) -> Bool {
        return ScribdURLParser.isScribdHost(url.host)
    }

    public func inspect(_ url: URL) async throws -> ProviderResult {
        guard let info = ScribdURLParser.parse(url) else {
            throw ProviderError.unhandledURL(url)
        }

        // Format a human-readable title from slug if available
        var title = info.slug?
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
        if title == nil || title?.isEmpty == true {
            title = "Documento Scribd \(info.id)"
        }

        // Attempt to fetch public OpenGraph title or page title gently
        var metadata = DocumentMetadata(
            title: title,
            contentType: info.resourceType
        )

        // Non-intrusive HEAD or GET check to verify link existence and extract public <title>
        do {
            var request = URLRequest(url: info.canonicalURL)
            request.httpMethod = "GET"
            request.timeoutInterval = 10.0
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

            // Only fetch small initial snippet if possible
            let (data, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 404 {
                    // Even if 404 or unlisted, technically classified as restricted / no public download
                    metadata.title = metadata.title ?? "Documento Scribd \(info.id)"
                }

                if httpResponse.statusCode == 200, let html = String(data: data.prefix(16384), encoding: .utf8) {
                    // Extract <title> or <meta property="og:title" content="...">
                    if let ogTitle = extractMetaContent(html: html, property: "og:title") {
                        metadata.title = ogTitle
                    } else if let pageTitle = extractTagContent(html: html, tag: "title") {
                        metadata.title = pageTitle
                    }
                    if let ogDesc = extractMetaContent(html: html, property: "og:description") {
                        metadata.subject = ogDesc
                    }
                }
            }
        } catch {
            AppLogger.provider.debug("No se pudo contactar con la red para metadatos públicos de Scribd: \(error.localizedDescription)")
            // Gracefully fall back to URL-derived metadata
        }

        // Educational policy: standard Scribd documents are protected / proprietary
        return ProviderResult(
            providerIdentifier: identifier,
            originalURL: url,
            canonicalURL: info.canonicalURL,
            resourceStatus: .restricted,
            metadata: metadata,
            downloadableURL: nil,
            publicId: info.id,
            slug: info.slug,
            note: "Recurso clasificado como restringido. No se permite la descarga directa no autorizada. Para validar el pipeline completo use un enlace de prueba scribemac://fixture o un PDF público."
        )
    }

    public func resolveDownload(_ url: URL) async throws -> DownloadResult {
        throw ProviderError.restrictedResource(
            "El documento está clasificado técnicamente como restringido (sin descarga pública autorizada). Folium respeta los términos del servicio y no elude mecanismos de acceso. Para estudiar el pipeline de descarga y procesamiento, utilice un enlace scribemac://fixture/... o un PDF directo."
        )
    }

    // MARK: - HTML Helpers for Public Metadata
    private func extractMetaContent(html: String, property: String) -> String? {
        let pattern = #"<meta\s+property=["']\#(property)["']\s+content=["']([^"']+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        if let match = regex.firstMatch(in: html, options: [], range: range),
           let contentRange = Range(match.range(at: 1), in: html) {
            return String(html[contentRange])
                .replacingOccurrences(of: " | Scribd", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func extractTagContent(html: String, tag: String) -> String? {
        let pattern = #"<\#(tag)>(.*?)</\#(tag)>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        if let match = regex.firstMatch(in: html, options: [], range: range),
           let contentRange = Range(match.range(at: 1), in: html) {
            return String(html[contentRange])
                .replacingOccurrences(of: " | Scribd", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}
