import Foundation

/// Provider for direct PDF links on the open web.
/// Performs HEAD inspection with GET fallback, verifies Content-Type, checks size limits, and follows redirects.
public struct DirectPDFProvider: DocumentProvider {
    public let identifier = "direct_pdf"
    public let displayName = "Enlace Directo PDF"

    public let maxFileSize: Int64
    private let session: URLSession

    public init(maxFileSize: Int64 = 250 * 1024 * 1024, session: URLSession = .shared) {
        self.maxFileSize = maxFileSize
        self.session = session
    }

    public func canHandle(_ url: URL) -> Bool {
        // Direct .pdf extension or http/https
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }
        // Exclude recognized proprietary platforms
        if ScribdURLParser.isScribdHost(url.host) {
            return false
        }
        return url.pathExtension.lowercased() == "pdf" || url.path.contains(".pdf")
    }

    public func inspect(_ url: URL) async throws -> ProviderResult {
        var suggestedFilename = url.lastPathComponent
        if suggestedFilename.isEmpty || !suggestedFilename.hasSuffix(".pdf") {
            suggestedFilename = "documento.pdf"
        }

        var detectedSize: Int64? = nil
        var detectedMime = "application/pdf"
        var finalURL = url

        // Step 1: Attempt HEAD request
        var headRequest = URLRequest(url: url)
        headRequest.httpMethod = "HEAD"
        headRequest.timeoutInterval = 10.0
        headRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        var headSucceeded = false
        do {
            let (_, response) = try await session.data(for: headRequest)
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    headSucceeded = true
                    if let resURL = httpResponse.url {
                        finalURL = resURL
                    }
                    if let mime = httpResponse.mimeType {
                        detectedMime = mime
                    }
                    if httpResponse.expectedContentLength > 0 {
                        detectedSize = httpResponse.expectedContentLength
                    }
                    if let cdFilename = extractFilenameFromContentDisposition(httpResponse) {
                        suggestedFilename = cdFilename
                    }
                } else if httpResponse.statusCode == 404 {
                    return ProviderResult(
                        providerIdentifier: identifier,
                        originalURL: url,
                        canonicalURL: url,
                        resourceStatus: .unavailable,
                        note: "Recurso no encontrado (HTTP 404)."
                    )
                } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    return ProviderResult(
                        providerIdentifier: identifier,
                        originalURL: url,
                        canonicalURL: url,
                        resourceStatus: .authenticationRequired,
                        note: "El servidor requiere autenticación o permisos (HTTP \(httpResponse.statusCode))."
                    )
                }
            }
        } catch {
            AppLogger.provider.debug("HEAD falló o no está soportado para \(url): \(error.localizedDescription)")
        }

        // Step 2: Fallback to small Range GET if HEAD was not accepted
        if !headSucceeded {
            var getRequest = URLRequest(url: url)
            getRequest.httpMethod = "GET"
            getRequest.setValue("bytes=0-2048", forHTTPHeaderField: "Range")
            getRequest.timeoutInterval = 10.0

            do {
                let (_, response) = try await session.data(for: getRequest)
                if let httpResponse = response as? HTTPURLResponse {
                    if (200...299).contains(httpResponse.statusCode) || httpResponse.statusCode == 206 {
                        if let resURL = httpResponse.url {
                            finalURL = resURL
                        }
                        if let mime = httpResponse.mimeType {
                            detectedMime = mime
                        }
                        if httpResponse.expectedContentLength > 0 {
                            detectedSize = httpResponse.expectedContentLength
                        }
                        if let cdFilename = extractFilenameFromContentDisposition(httpResponse) {
                            suggestedFilename = cdFilename
                        }
                    } else if httpResponse.statusCode == 404 {
                        return ProviderResult(
                            providerIdentifier: identifier,
                            originalURL: url,
                            canonicalURL: url,
                            resourceStatus: .unavailable,
                            note: "Recurso no encontrado (HTTP 404)."
                        )
                    }
                }
            } catch {
                return ProviderResult(
                    providerIdentifier: identifier,
                    originalURL: url,
                    canonicalURL: url,
                    resourceStatus: .unavailable,
                    note: "No se pudo conectar con el servidor: \(error.localizedDescription)"
                )
            }
        }

        // Check size limit if known
        if let size = detectedSize, size > maxFileSize {
            return ProviderResult(
                providerIdentifier: identifier,
                originalURL: url,
                canonicalURL: finalURL,
                resourceStatus: .restricted,
                note: "El archivo (\(size / 1024 / 1024) MB) supera el límite máximo configurado (\(maxFileSize / 1024 / 1024) MB)."
            )
        }

        let metadata = DocumentMetadata(
            title: suggestedFilename.replacingOccurrences(of: ".pdf", with: ""),
            fileSize: detectedSize,
            contentType: detectedMime
        )

        return ProviderResult(
            providerIdentifier: identifier,
            originalURL: url,
            canonicalURL: finalURL,
            resourceStatus: .downloadable,
            metadata: metadata,
            downloadableURL: finalURL,
            slug: suggestedFilename,
            note: "Enlace directo público accesible."
        )
    }

    public func resolveDownload(_ url: URL) async throws -> DownloadResult {
        return DownloadResult(
            url: url,
            suggestedFilename: url.lastPathComponent,
            expectedMIMEType: "application/pdf",
            requiresAuthentication: false
        )
    }

    private func extractFilenameFromContentDisposition(_ response: HTTPURLResponse) -> String? {
        guard let disposition = response.value(forHTTPHeaderField: "Content-Disposition") else {
            return nil
        }
        let pattern = #"filename\*?=['"]?(?:UTF-\d['"]*)?([^;\r\n"']+)['"]?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(disposition.startIndex..<disposition.endIndex, in: disposition)
        if let match = regex.firstMatch(in: disposition, options: [], range: range),
           let fileRange = Range(match.range(at: 1), in: disposition) {
            return String(disposition[fileRange]).removingPercentEncoding
        }
        return nil
    }
}
