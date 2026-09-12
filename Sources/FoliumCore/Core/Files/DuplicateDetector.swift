import Foundation

public struct DuplicateDetector: Sendable {

    public enum Resolution: Equatable, Sendable {
        /// An exact duplicate already exists at this path (identical hash and file size).
        case exactDuplicate(existingURL: URL)
        /// A new, unique destination URL where the file can safely be moved without overwriting.
        case uniqueDestination(URL)
    }

    /// Resolves destination for a downloaded file.
    /// Checks for duplicates using hash + size, never silently overwrites, and numbers variants when needed.
    public static func resolveDestination(
        desiredFilename: String,
        sourceFileSize: Int64,
        sourceSHA256: String,
        destinationDirectory: URL
    ) throws -> Resolution {
        let fileManager = FileManager.default
        let cleanName = FileOrganizer.sanitizeFilename(desiredFilename)
        let baseName = String(cleanName.dropLast(4)) // Remove .pdf

        var candidateURL = destinationDirectory.appendingPathComponent(cleanName)

        if !fileManager.fileExists(atPath: candidateURL.path) {
            return .uniqueDestination(candidateURL)
        }

        // Check if existing file is an exact duplicate
        if isExactMatch(fileURL: candidateURL, targetSize: sourceFileSize, targetSHA: sourceSHA256) {
            return .exactDuplicate(existingURL: candidateURL)
        }

        // If file exists with different content, generate incremented suffix: "Title (2).pdf", etc.
        var counter = 2
        while true {
            let incrementedName = "\(baseName) (\(counter)).pdf"
            candidateURL = destinationDirectory.appendingPathComponent(incrementedName)

            if !fileManager.fileExists(atPath: candidateURL.path) {
                return .uniqueDestination(candidateURL)
            }

            // Check if one of the existing incremented files is the exact duplicate
            if isExactMatch(fileURL: candidateURL, targetSize: sourceFileSize, targetSHA: sourceSHA256) {
                return .exactDuplicate(existingURL: candidateURL)
            }

            counter += 1
            if counter > 1000 {
                // Safeguard against unbounded loops
                let fallbackName = "\(baseName)_\(UUID().uuidString.prefix(8)).pdf"
                return .uniqueDestination(destinationDirectory.appendingPathComponent(fallbackName))
            }
        }
    }

    private static func isExactMatch(fileURL: URL, targetSize: Int64, targetSHA: String) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let existingSize = attributes[.size] as? Int64 else {
            return false
        }

        if existingSize != targetSize {
            return false
        }

        guard let existingSHA = try? FileHasher.sha256(for: fileURL) else {
            return false
        }

        return existingSHA.lowercased() == targetSHA.lowercased()
    }
}
