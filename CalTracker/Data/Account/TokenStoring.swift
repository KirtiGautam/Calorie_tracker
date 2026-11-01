/// Keeps the signed-in account's tokens between launches.
///
/// The methods are `async` so an implementation can do its work off the main actor.
nonisolated protocol TokenStoring: Sendable {
    /// Returns the saved tokens, or `nil` when none are saved or they can't be decoded.
    ///
    /// - Throws: When the store can't be read right now, for example before the first unlock after a restart.
    func load() async throws -> GramwiseTokenPair?

    /// Replaces the saved tokens with `tokens`.
    func save(_ tokens: GramwiseTokenPair) async throws

    /// Removes the saved tokens. Succeeds when there were none.
    func clear() async throws
}
