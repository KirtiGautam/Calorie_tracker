/// Keeps tokens in memory only, for previews and tests, so they always start signed out.
final class InMemoryTokenStore: TokenStoring {
    /// The saved tokens.
    private(set) var tokens: GramwiseTokenPair?

    /// Creates a store holding `tokens`, signed out by default.
    init(tokens: GramwiseTokenPair? = nil) {
        self.tokens = tokens
    }

    func load() -> GramwiseTokenPair? {
        tokens
    }

    func save(_ tokens: GramwiseTokenPair) throws {
        self.tokens = tokens
    }

    func clear() throws {
        tokens = nil
    }
}
