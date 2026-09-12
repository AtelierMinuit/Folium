import Foundation

/// Lifecycle status for a document processing / download job (legacy compatibility).
public enum DownloadStatus: String, Codable, Sendable, CustomStringConvertible {
    case idle
    case inspecting
    case queued
    case downloading
    case validating
    case completed
    case failed
    case cancelled

    public var description: String {
        switch self {
        case .idle: return "En espera"
        case .inspecting: return "Analizando"
        case .queued: return "En cola"
        case .downloading: return "Descargando"
        case .validating: return "Validando"
        case .completed: return "Completado"
        case .failed: return "Fallido"
        case .cancelled: return "Cancelado"
        }
    }
}

/// A comprehensive job tracking the complete lifecycle of a document processing request.
public struct DocumentJob: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public let originalURL: URL
    public var canonicalURL: URL?
    public var provider: String?
    public var title: String?
    public var author: String?
    public var resourceStatus: ResourceStatus
    public var state: DocumentState
    public var progress: Double // 0.0 to 1.0
    public var bytesDownloaded: Int64
    public var totalBytes: Int64
    public var speedBytesPerSecond: Double
    public var createdAt: Date
    public var completedAt: Date?
    public var localPath: String?
    public var mimeType: String?
    public var fileSize: Int64?
    public var sha256: String?
    public var sourceURL: URL?
    public var errorMessage: String?
    public var etag: String?
    public var serverName: String?
    public var supportsRanges: Bool
    public var transitionLog: [StateTransitionEvent]

    /// Legacy bridge mapping `downloadStatus` to/from `state`
    public var downloadStatus: DownloadStatus {
        get {
            switch state {
            case .received, .parsing, .resolvable: return .idle
            case .inspecting: return .inspecting
            case .queued: return .queued
            case .downloading: return .downloading
            case .validating, .finalizing: return .validating
            case .completed: return .completed
            case .failed, .restricted, .unsupported, .authenticationRequired: return .failed
            case .cancelled: return .cancelled
            }
        }
        set {
            switch newValue {
            case .idle: state = .received
            case .inspecting: state = .inspecting
            case .queued: state = .queued
            case .downloading: state = .downloading
            case .validating: state = .validating
            case .completed: state = .completed
            case .failed: state = .failed
            case .cancelled: state = .cancelled
            }
        }
    }

    public init(
        id: UUID = UUID(),
        originalURL: URL,
        canonicalURL: URL? = nil,
        provider: String? = nil,
        title: String? = nil,
        author: String? = nil,
        resourceStatus: ResourceStatus = .downloadable,
        state: DocumentState = .received,
        downloadStatus: DownloadStatus? = nil,
        progress: Double = 0.0,
        bytesDownloaded: Int64 = 0,
        totalBytes: Int64 = 0,
        speedBytesPerSecond: Double = 0.0,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        localPath: String? = nil,
        mimeType: String? = nil,
        fileSize: Int64? = nil,
        sha256: String? = nil,
        sourceURL: URL? = nil,
        errorMessage: String? = nil,
        etag: String? = nil,
        serverName: String? = nil,
        supportsRanges: Bool = false,
        transitionLog: [StateTransitionEvent] = []
    ) {
        self.id = id
        self.originalURL = originalURL
        self.canonicalURL = canonicalURL
        self.provider = provider
        self.title = title
        self.author = author
        self.resourceStatus = resourceStatus
        if let ds = downloadStatus {
            switch ds {
            case .idle: self.state = .received
            case .inspecting: self.state = .inspecting
            case .queued: self.state = .queued
            case .downloading: self.state = .downloading
            case .validating: self.state = .validating
            case .completed: self.state = .completed
            case .failed: self.state = .failed
            case .cancelled: self.state = .cancelled
            }
        } else {
            self.state = state
        }
        self.progress = progress
        self.bytesDownloaded = bytesDownloaded
        self.totalBytes = totalBytes
        self.speedBytesPerSecond = speedBytesPerSecond
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.localPath = localPath
        self.mimeType = mimeType
        self.fileSize = fileSize
        self.sha256 = sha256
        self.sourceURL = sourceURL
        self.errorMessage = errorMessage
        self.etag = etag
        self.serverName = serverName
        self.supportsRanges = supportsRanges
        self.transitionLog = transitionLog

        if self.transitionLog.isEmpty {
            self.transitionLog.append(
                StateTransitionEvent(
                    timestamp: createdAt,
                    state: self.state,
                    message: "Trabajo inicializado para: \(originalURL.host ?? originalURL.absoluteString)"
                )
            )
        }
    }

    /// Records a technical state transition with a human-readable message and timestamp.
    public mutating func recordTransition(
        _ newState: DocumentState,
        message: String,
        metadata: [String: String]? = nil
    ) {
        self.state = newState
        let event = StateTransitionEvent(
            timestamp: Date(),
            state: newState,
            message: message,
            metadata: metadata
        )
        self.transitionLog.append(event)
    }
}
