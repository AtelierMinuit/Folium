import Foundation
import SwiftData

/// Persisted configuration for known providers.
@Model
public final class ProviderRecord {
    @Attribute(.unique) public var identifier: String
    public var displayName: String
    public var isEnabled: Bool
    public var supportedSchemes: [String]
    public var isFixture: Bool
    public var lastUsedAt: Date?

    public init(
        identifier: String,
        displayName: String,
        isEnabled: Bool = true,
        supportedSchemes: [String] = [],
        isFixture: Bool = false,
        lastUsedAt: Date? = nil
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.isEnabled = isEnabled
        self.supportedSchemes = supportedSchemes
        self.isFixture = isFixture
        self.lastUsedAt = lastUsedAt
    }
}
