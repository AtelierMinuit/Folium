import Foundation

/// Central registry managing all document providers.
/// Prioritizes providers and resolves the best matching handler for any given URL.
public final class ProviderRegistry: @unchecked Sendable {
    public static let shared = ProviderRegistry()

    private let lock = NSLock()
    private var providers: [any DocumentProvider] = []

    public init() {
        registerDefaultProviders()
    }

    /// Registers default providers in evaluation order.
    public func registerDefaultProviders() {
        lock.lock()
        defer { lock.unlock() }

        providers = [
            MockRestrictedProvider(),
            ScribdMetadataProvider(),
            OpenRepositoryProvider(),
            DirectPDFProvider()
        ]
    }

    /// Registers a custom provider at the front of the chain.
    public func register(_ provider: any DocumentProvider) {
        lock.lock()
        defer { lock.unlock() }
        providers.insert(provider, at: 0)
    }

    /// Returns the first provider capable of handling the specified URL.
    public func provider(for url: URL) -> (any DocumentProvider)? {
        lock.lock()
        defer { lock.unlock() }
        return providers.first { $0.canHandle(url) }
    }

    /// Returns all registered providers.
    public var allProviders: [any DocumentProvider] {
        lock.lock()
        defer { lock.unlock() }
        return providers
    }
}
