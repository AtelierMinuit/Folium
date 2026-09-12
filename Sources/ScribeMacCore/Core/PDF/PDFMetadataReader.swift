import Foundation
import PDFKit

/// Reads document metadata from a validated PDF document.
public struct PDFMetadataReader: Sendable {

    public static func readMetadata(from fileURL: URL) -> DocumentMetadata {
        guard let doc = PDFDocument(url: fileURL) else {
            return DocumentMetadata()
        }

        let attributes = doc.documentAttributes ?? [:]

        let title = attributes[PDFDocumentAttribute.titleAttribute] as? String
        let author = attributes[PDFDocumentAttribute.authorAttribute] as? String
        let subject = attributes[PDFDocumentAttribute.subjectAttribute] as? String
        let creator = attributes[PDFDocumentAttribute.creatorAttribute] as? String
        let producer = attributes[PDFDocumentAttribute.producerAttribute] as? String
        let creationDate = attributes[PDFDocumentAttribute.creationDateAttribute] as? Date
        let modificationDate = attributes[PDFDocumentAttribute.modificationDateAttribute] as? Date

        var keywords: [String] = []
        if let rawKeywords = attributes[PDFDocumentAttribute.keywordsAttribute] as? [String] {
            keywords = rawKeywords
        } else if let kwString = attributes[PDFDocumentAttribute.keywordsAttribute] as? String {
            keywords = kwString.components(separatedBy: CharacterSet(charactersIn: ",;")).map { $0.trimmingCharacters(in: .whitespaces) }
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? nil

        return DocumentMetadata(
            title: title,
            author: author,
            subject: subject,
            creator: creator,
            producer: producer,
            pageCount: doc.pageCount,
            fileSize: fileSize,
            contentType: "application/pdf",
            creationDate: creationDate,
            modificationDate: modificationDate,
            keywords: keywords,
            isEncrypted: doc.isEncrypted
        )
    }
}
