import SwiftUI
import Observation
import ScribeMacCore
import AppKit

@Observable
@MainActor
public final class AppEnvironment {
    public let registry: ProviderRegistry
    public var organizer: FileOrganizer
    public let queue: DownloadQueue
    public let store: SwiftDataStore

    // User settings
    public var autoCheckClipboard: Bool {
        didSet {
            UserDefaults.standard.set(autoCheckClipboard, forKey: "ScribeMac_AutoCheckClipboard")
        }
    }

    public var maxFileSizeBytes: Int64 {
        didSet {
            UserDefaults.standard.set(maxFileSizeBytes, forKey: "ScribeMac_MaxFileSizeBytes")
        }
    }

    public init(store: SwiftDataStore = .shared) {
        let initialOrganizer = FileOrganizer()
        let manager = DownloadManager(organizer: initialOrganizer)
        self.registry = ProviderRegistry.shared
        self.organizer = initialOrganizer
        self.queue = DownloadQueue(downloadManager: manager)
        self.store = store

        self.autoCheckClipboard = UserDefaults.standard.bool(forKey: "ScribeMac_AutoCheckClipboard")
        let savedMax = UserDefaults.standard.integer(forKey: "ScribeMac_MaxFileSizeBytes")
        self.maxFileSizeBytes = savedMax > 0 ? Int64(savedMax) : (250 * 1024 * 1024)

        try? initialOrganizer.createDirectoriesIfNeeded()
    }

    public func updateDownloadDirectory(_ newDirectory: URL) {
        self.organizer = FileOrganizer(rootDirectory: newDirectory)
        try? self.organizer.createDirectoriesIfNeeded()
    }
}
