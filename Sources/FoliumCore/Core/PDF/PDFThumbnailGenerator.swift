import Foundation
import PDFKit
import AppKit

public struct PDFThumbnailGenerator: Sendable {

    /// Generates an NSImage thumbnail for the first page of a PDF document at given size.
    @MainActor
    public static func generateThumbnail(for fileURL: URL, size: CGSize = CGSize(width: 300, height: 400)) -> NSImage? {
        guard let doc = PDFDocument(url: fileURL),
              let page = doc.page(at: 0) else {
            return nil
        }
        return page.thumbnail(of: size, for: .cropBox)
    }

    /// Generates and saves a PNG thumbnail to the specified destination URL.
    @MainActor
    public static func saveThumbnail(for fileURL: URL, destinationURL: URL, size: CGSize = CGSize(width: 300, height: 400)) throws {
        guard let image = generateThumbnail(for: fileURL, size: size) else {
            throw PDFValidationError.cannotOpenWithPDFKit
        }

        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            throw PDFValidationError.readFailure("No se pudo generar representación PNG de la miniatura.")
        }

        try pngData.write(to: destinationURL)
    }
}
