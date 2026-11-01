/// Keeps the signed-in account's tokens between launches.
protocol TokenStoring {
    /// Returns the saved tokens, or `nil` when there are none or they can't be read.
    func load() -> GramwiseTokenPair?

    /// Replaces the saved tokens with `tokens`.
    func save(_ tokens: GramwiseTokenPair) throws

    /// Removes the saved tokens. Succeeds when there were none.
    func clear() throws
}
