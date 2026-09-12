import Foundation

/// Represents an immutable, timestamped event in the technical audit trail of a document job.
public struct StateTransitionEvent: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let state: DocumentState
    public let message: String
    public let metadata: [String: String]?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        state: DocumentState,
        message: String,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.state = state
        self.message = message
        self.metadata = metadata
    }

    /// Formatted time string: "HH:mm:ss"
    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}
