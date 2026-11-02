/// One page of a food search: the text, which page, and the filters to narrow it by.
nonisolated struct FoodSearchRequest: Hashable, Sendable {
    /// The trimmed search text.
    var query: String

    /// The page to fetch, starting at 1.
    var page = 1

    /// The filters to apply. Providers ignore the ones they can't support.
    var filters = FoodSearchFilters()
}
