import Foundation

public struct FileOrganizer: Sendable {
    public let rootDirectory: URL

    public var incomingDirectory: URL {
        rootDirectory.appendingPathComponent("Incoming", isDirectory: true)
    }

    public var libraryDirectory: URL {
        rootDirectory.appendingPathComponent("Library", isDirectory: true)
    }

    public var failedDirectory: URL {
        rootDirectory.appendingPathComponent("Failed", isDirectory: true)
    }

    public var logsDirectory: URL {
        rootDirectory.appendingPathComponent("Logs", isDirectory: true)
    }

    /// Initializes with default `~/Downloads/ScribeMac/` or a custom root directory.
    public init(rootDirectory: URL? = nil) {
        if let root = rootDirectory {
            self.rootDirectory = root
        } else {
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads", isDirectory: true)
            self.rootDirectory = downloads.appendingPathComponent("ScribeMac", isDirectory: true)
        }
    }

    /// Ensures that all required directory tiers exist on disk with proper permissions.
    public func createDirectoriesIfNeeded() throws {
        let fileManager = FileManager.default
        let dirs = [incomingDirectory, libraryDirectory, failedDirectory, logsDirectory]

        for dir in dirs {
            if !fileManager.fileExists(atPath: dir.path) {
                try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            }
        }
    }

    /// Sanitizes filename to prevent directory traversal and illegal macOS / POSIX filesystem characters.
    /// Strips `/`, `:`, null bytes, control characters, and limits string length.
    public static func sanitizeFilename(_ rawName: String) -> String {
        var clean = rawName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove path traversal and illegal characters: / : \ ? * < > | "
        let illegalCharacters = CharacterSet(charactersIn: "/:\\?*<>|\"\0")
            .union(CharacterSet.controlCharacters)
            .union(CharacterSet.newlines)

        clean = clean.components(separatedBy: illegalCharacters).joined(separator: "_")

        // Prevent leading dots (hidden files) or dot-dot traversal
        while clean.hasPrefix(".") {
            clean.removeFirst()
        }

        // Collapse multiple underscores
        while clean.contains("__") {
            clean = clean.replacingOccurrences(of: "__", with: "_")
        }

        // Ensure reasonable length (max 120 chars before extension)
        let hasPdf = clean.lowercased().hasSuffix(".pdf")
        var base = hasPdf ? String(clean.dropLast(4)) : clean
        if base.count > 120 {
            base = String(base.prefix(120))
        }

        base = base.trimmingCharacters(in: CharacterSet(charactersIn: " ._"))
        if base.isEmpty {
            base = "documento"
        }

        return "\(base).pdf"
    }

    /// Generates safe author-title formatted filename
    public static func formattedFilename(author: String?, title: String?, fallbackId: String? = nil) -> String {
        let safeAuthor = author?.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)

        var combined = ""
        if let a = safeAuthor, !a.isEmpty, let t = safeTitle, !t.isEmpty {
            combined = "\(a) - \(t)"
        } else if let t = safeTitle, !t.isEmpty {
            combined = t
        } else if let a = safeAuthor, !a.isEmpty {
            combined = "Documento de \(a)"
        } else if let fid = fallbackId, !fid.isEmpty {
            combined = "Documento-\(fid)"
        } else {
            combined = "Documento"
        }

        return sanitizeFilename(combined)
    }
}
