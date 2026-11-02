/// A database that can be searched for foods by name, one page at a time.
nonisolated protocol FoodSearchProvider: Sendable {
    /// Returns one page of foods matching `request`.
    func search(_ request: FoodSearchRequest) async throws -> FoodSearchPage
}
