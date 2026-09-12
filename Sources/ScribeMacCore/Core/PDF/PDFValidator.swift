import Foundation
import PDFKit

public enum PDFValidationError: Error, LocalizedError, Equatable {
    case fileNotFound(URL)
    case emptyFile
    case fileTooSmall(Int64)
    case invalidMagicBytes(found: String)
    case disguisedHTML
    case cannotOpenWithPDFKit
    case zeroPages
    case documentIsLocked
    case readFailure(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "Archivo no encontrado: \(url.path)"
        case .emptyFile:
            return "El archivo está vacío (0 bytes)."
        case .fileTooSmall(let size):
            return "Archivo demasiado pequeño para ser un PDF válido (\(size) bytes)."
        case .invalidMagicBytes(let found):
            return "Cabecera mágica no válida. Se esperaba '%PDF-', se encontró '\(found)'."
        case .disguisedHTML:
            return "El archivo es contenido HTML disfrazado como PDF (posible página de error o bloqueo)."
        case .cannotOpenWithPDFKit:
            return "PDFKit no pudo inicializar el documento (archivo corrupto o estructura dañada)."
        case .zeroPages:
            return "El documento PDF no contiene páginas legibles."
        case .documentIsLocked:
            return "El documento PDF está protegido por contraseña o cifrado."
        case .readFailure(let reason):
            return "Error al leer archivo: \(reason)"
        }
    }
}

public struct PDFValidationResult: Sendable {
    public let isValid: Bool
    public let pageCount: Int
    public let isEncrypted: Bool
    public let fileSize: Int64
    public let pdfVersion: String?
}

/// Validates downloaded PDF files against magic byte signatures and structural PDFKit requirements.
public struct PDFValidator: Sendable {

    private static let pdfMagicBytes = Data([0x25, 0x50, 0x44, 0x46, 0x2D]) // "%PDF-"

    public init() {}

    /// Performs comprehensive validation on a PDF file.
    public static func validate(at fileURL: URL) throws -> PDFValidationResult {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw PDFValidationError.fileNotFound(fileURL)
        }

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attributes[.size] as? Int64 else {
            throw PDFValidationError.readFailure("No se pudieron obtener atributos del archivo.")
        }

        guard size > 0 else {
            throw PDFValidationError.emptyFile
        }

        guard size >= 8 else {
            throw PDFValidationError.fileTooSmall(size)
        }

        // Check magic bytes %PDF-
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
            throw PDFValidationError.readFailure("No se pudo abrir el archivo para lectura.")
        }
        defer { try? handle.close() }

        let headerData = handle.readData(ofLength: 32)
        guard headerData.count >= 5 else {
            throw PDFValidationError.fileTooSmall(size)
        }

        // Check if disguised HTML
        if let headerString = String(data: headerData, encoding: .ascii)?.lowercased() {
            if headerString.hasPrefix("<!doc") || headerString.hasPrefix("<html") || headerString.hasPrefix("<?xml") {
                throw PDFValidationError.disguisedHTML
            }
        }

        let prefix5 = headerData.prefix(5)
        guard prefix5 == pdfMagicBytes else {
            let found = String(data: prefix5, encoding: .ascii) ?? "datos binarios desconocidos"
            throw PDFValidationError.invalidMagicBytes(found: found)
        }

        var pdfVersion: String? = nil
        if let fullHeader = String(data: headerData, encoding: .ascii) {
            let components = fullHeader.components(separatedBy: .whitespacesAndNewlines)
            if let first = components.first, first.hasPrefix("%PDF-") {
                pdfVersion = first.replacingOccurrences(of: "%PDF-", with: "")
            }
        }

        // Verify with PDFKit
        guard let pdfDoc = PDFDocument(url: fileURL) else {
            throw PDFValidationError.cannotOpenWithPDFKit
        }

        if pdfDoc.isLocked {
            throw PDFValidationError.documentIsLocked
        }

        let pages = pdfDoc.pageCount
        guard pages > 0 else {
            throw PDFValidationError.zeroPages
        }

        // Check readability of first page
        guard pdfDoc.page(at: 0) != nil else {
            throw PDFValidationError.cannotOpenWithPDFKit
        }

        return PDFValidationResult(
            isValid: true,
            pageCount: pages,
            isEncrypted: pdfDoc.isEncrypted,
            fileSize: size,
            pdfVersion: pdfVersion
        )
    }
}
