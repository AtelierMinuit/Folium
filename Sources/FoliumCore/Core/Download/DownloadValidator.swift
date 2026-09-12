import Foundation

public enum DownloadValidationError: Error, LocalizedError, Equatable {
    case invalidHTTPStatus(statusCode: Int)
    case invalidMIMEType(expected: String, received: String?)
    case fileExceedsMaximumSize(size: Int64, max: Int64)
    case zeroBytePayload
    case missingResponse

    public var errorDescription: String? {
        switch self {
        case .invalidHTTPStatus(let code):
            return "El servidor devolvió un código HTTP de error: \(code)."
        case .invalidMIMEType(let expected, let received):
            return "Tipo MIME no esperado. Esperado: '\(expected)', recibido: '\(received ?? "ninguno")'."
        case .fileExceedsMaximumSize(let size, let max):
            return "El archivo supera el tamaño máximo permitido (\(size / 1024 / 1024) MB > \(max / 1024 / 1024) MB)."
        case .zeroBytePayload:
            return "La descarga contiene 0 bytes."
        case .missingResponse:
            return "No se recibió respuesta HTTP del servidor."
        }
    }
}

public struct DownloadValidator: Sendable {
    public let maxSizeBytes: Int64
    public let allowedMimeTypes: Set<String>

    public init(
        maxSizeBytes: Int64 = 250 * 1024 * 1024,
        allowedMimeTypes: Set<String> = [
            "application/pdf",
            "application/x-pdf",
            "application/acrobat",
            "applications/vnd.pdf",
            "text/pdf",
            "application/octet-stream",
            "binary/octet-stream"
        ]
    ) {
        self.maxSizeBytes = maxSizeBytes
        self.allowedMimeTypes = allowedMimeTypes
    }

    /// Validates HTTP response headers before or after receiving body.
    public func validateResponse(_ response: URLResponse?) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DownloadValidationError.missingResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw DownloadValidationError.invalidHTTPStatus(statusCode: httpResponse.statusCode)
        }

        if let mime = httpResponse.mimeType?.lowercased(), !allowedMimeTypes.contains(mime) {
            // Check if URL ends with .pdf
            let urlEndsWithPDF = httpResponse.url?.pathExtension.lowercased() == "pdf"
            if !urlEndsWithPDF {
                throw DownloadValidationError.invalidMIMEType(expected: "application/pdf", received: mime)
            }
        }

        if httpResponse.expectedContentLength > 0 && httpResponse.expectedContentLength > maxSizeBytes {
            throw DownloadValidationError.fileExceedsMaximumSize(size: httpResponse.expectedContentLength, max: maxSizeBytes)
        }
    }

    /// Validates local downloaded file attributes.
    public func validateLocalFile(at url: URL) throws {
        guard let attr = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attr[.size] as? Int64 else {
            throw DownloadValidationError.zeroBytePayload
        }

        guard size > 0 else {
            throw DownloadValidationError.zeroBytePayload
        }

        guard size <= maxSizeBytes else {
            throw DownloadValidationError.fileExceedsMaximumSize(size: size, max: maxSizeBytes)
        }
    }
}
