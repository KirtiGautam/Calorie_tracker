/// A database that can be searched for foods by name.
nonisolated protocol FoodSearchProvider: Sendable {
    /// Returns the foods matching `query`.
    func search(_ query: String) async throws -> [FoodItem]
}
