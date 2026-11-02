/// One page of a food search: the text and which page.
nonisolated struct FoodSearchRequest: Hashable, Sendable {
    /// The trimmed search text.
    var query: String

    /// The page to fetch, starting at 1.
    var page = 1
}
