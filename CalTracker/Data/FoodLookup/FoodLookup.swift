/// Looks foods up again by their source-prefixed IDs, to restore a log from the server.
nonisolated protocol FoodLookup: Sendable {
    /// Returns the foods it could find, keyed by ID.
    ///
    /// It never throws: IDs it can't look up are left out, and the caller falls back to what it already has.
    func foods(withIDs ids: Set<String>) async -> [String: FoodItem]
}
