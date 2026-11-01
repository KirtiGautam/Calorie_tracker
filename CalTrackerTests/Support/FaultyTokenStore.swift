import Security
@testable import CalTracker

/// A `TokenStoring` double whose calls can be told to fail, like a locked Keychain or one that refuses a write.
@MainActor
final class FaultyTokenStore: TokenStoring {
    /// The saved tokens.
    private(set) var tokens: GramwiseTokenPair?

    /// When set, `load()` throws this error, as the Keychain does before the first unlock after a restart.
    var loadError: KeychainError?

    /// When set, `save(_:)` and `clear()` throw this error and change nothing.
    var writeError: KeychainError?

    /// Creates a store holding `tokens`.
    init(tokens: GramwiseTokenPair? = nil) {
        self.tokens = tokens
    }

    @MainActor func load() async throws -> GramwiseTokenPair? {
        if let loadError { throw loadError }
        return tokens
    }

    @MainActor func save(_ tokens: GramwiseTokenPair) async throws {
        if let writeError { throw writeError }
        self.tokens = tokens
    }

    @MainActor func clear() async throws {
        if let writeError { throw writeError }
        tokens = nil
    }
}
