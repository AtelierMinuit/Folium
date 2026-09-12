import Foundation
import os

public enum SecurityBookmarkError: LocalizedError, Sendable {
    case cannotCreateBookmark(String)
    case cannotResolveBookmark(String)
    case accessDenied(URL)

    public var errorDescription: String? {
        switch self {
        case .cannotCreateBookmark(let detail): return "Fallo al crear Security-Scoped Bookmark: \(detail)"
        case .cannotResolveBookmark(let detail): return "Fallo al resolver Security-Scoped Bookmark: \(detail)"
        case .accessDenied(let url): return "Permiso de acceso denegado por el Sandbox para: \(url.path)"
        }
    }
}

/// Thread-safe manager for Security-Scoped Bookmarks in macOS Sandboxed environment.
public actor SecurityScopedFolderManager {
    public static let shared = SecurityScopedFolderManager()

    private let userDefaultsKey = "com.scribemac.securityBookmark.rootDirectory"
    private var activeSecurityScopedURL: URL?

    private init() {}

    /// Serializes and stores a security-scoped bookmark after user picks folder in NSOpenPanel.
    public func saveBookmark(for url: URL) throws {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: userDefaultsKey)
            AppLogger.filesystem.info("Bookmark con ámbito de seguridad guardado para: \(url.path, privacy: .public)")
        } catch {
            AppLogger.filesystem.error("Error creando bookmark: \(error.localizedDescription)")
            throw SecurityBookmarkError.cannotCreateBookmark(error.localizedDescription)
        }
    }

    /// Resolves the URL from the stored bookmark and refreshes if stale.
    public func resolveStoredBookmark() throws -> URL? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return nil
        }

        var isStale = false
        do {
            let resolvedURL = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                AppLogger.filesystem.warning("El bookmark está obsoleto (stale). Re-guardando...")
                try saveBookmark(for: resolvedURL)
            }

            return resolvedURL
        } catch {
            AppLogger.filesystem.error("Error resolviendo bookmark: \(error.localizedDescription)")
            throw SecurityBookmarkError.cannotResolveBookmark(error.localizedDescription)
        }
    }

    /// Executes an I/O operation inside the security scope symmetrically.
    public func withActiveAccess<T: Sendable>(_ work: @Sendable (URL) throws -> T) throws -> T {
        guard let url = try resolveStoredBookmark() else {
            throw SecurityBookmarkError.cannotResolveBookmark("No existe un bookmark configurado.")
        }

        let accessGranted = url.startAccessingSecurityScopedResource()
        guard accessGranted else {
            throw SecurityBookmarkError.accessDenied(url)
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        return try work(url)
    }

    /// Activates long-term security access on startup.
    public func startLongTermAccess() throws -> URL? {
        if let current = activeSecurityScopedURL {
            return current
        }

        guard let url = try resolveStoredBookmark() else { return nil }

        guard url.startAccessingSecurityScopedResource() else {
            throw SecurityBookmarkError.accessDenied(url)
        }

        self.activeSecurityScopedURL = url
        AppLogger.filesystem.info("Acceso Sandbox activado para: \(url.path, privacy: .public)")
        return url
    }

    /// Releases long-term security access.
    public func stopLongTermAccess() {
        if let url = activeSecurityScopedURL {
            url.stopAccessingSecurityScopedResource()
            self.activeSecurityScopedURL = nil
            AppLogger.filesystem.info("Acceso Sandbox desactivado.")
        }
    }

    deinit {
        activeSecurityScopedURL?.stopAccessingSecurityScopedResource()
    }
}
