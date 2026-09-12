import Foundation
import CryptoKit

public enum FileHasherError: Error, LocalizedError {
    case fileNotFound(URL)
    case readFailure(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "Archivo no encontrado para cálculo de hash: \(url.path)"
        case .readFailure(let reason):
            return "Fallo al leer archivo en streaming: \(reason)"
        }
    }
}

/// Cryptographic file hashing using CryptoKit.
/// Streams file contents in 64KB chunks to compute SHA-256 without loading large files into RAM.
public struct FileHasher: Sendable {

    private static let bufferSize = 64 * 1024 // 64 KB

    /// Computes the SHA-256 hash of the file at the specified URL via streaming.
    public static func sha256(for fileURL: URL) throws -> String {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw FileHasherError.fileNotFound(fileURL)
        }

        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            throw FileHasherError.readFailure("No se pudo abrir el descriptor de archivo.")
        }
        defer {
            try? fileHandle.close()
        }

        var hasher = SHA256()

        while true {
            let data = fileHandle.readData(ofLength: bufferSize)
            if data.isEmpty {
                break
            }
            hasher.update(data: data)
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Computes SHA-256 for in-memory Data (for tests/fixtures).
    public static func sha256(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
