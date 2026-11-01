/// Keeps tokens in memory only, for previews and tests, so they always start signed out.
///
/// `TokenStoring` is `Sendable`, so the main actor isolation that guards `tokens` has to be spelled out.
@MainActor
final class InMemoryTokenStore: TokenStoring {
    /// The saved tokens.
    private(set) var tokens: GramwiseTokenPair?

    /// Creates a store holding `tokens`, signed out by default.
    init(tokens: GramwiseTokenPair? = nil) {
        self.tokens = tokens
    }

    @MainActor func load() async throws -> GramwiseTokenPair? {
        tokens
    }

    @MainActor func save(_ tokens: GramwiseTokenPair) async throws {
        self.tokens = tokens
    }

    @MainActor func clear() async throws {
        tokens = nil
    }
}
