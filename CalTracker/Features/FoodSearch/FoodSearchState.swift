/// Everything the food search screen renders.
struct FoodSearchState {
    /// The trimmed query the current results belong to.
    var query = ""

    /// The combined results for `query`.
    var results: Loadable<FoodSearchResults> = .idle
}
