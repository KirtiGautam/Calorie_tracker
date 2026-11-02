/// The next page to fetch from each source, or `nil` once a source has no more pages.
nonisolated struct FoodSearchCursor: Hashable, Sendable {
    /// The next USDA page, or `nil` when USDA has no more.
    var usda: Int?

    /// The next Open Food Facts page, or `nil` when Open Food Facts has no more.
    var openFoodFacts: Int?

    /// The cursor for a new search: page 1 from both sources.
    static let firstPage = FoodSearchCursor(usda: 1, openFoodFacts: 1)

    /// Whether at least one source has another page.
    var hasMore: Bool {
        usda != nil || openFoodFacts != nil
    }

    /// The next page for `source`.
    subscript(source: FoodSource) -> Int? {
        get {
            switch source {
            case .usda: usda
            case .openFoodFacts: openFoodFacts
            }
        }
        set {
            switch source {
            case .usda: usda = newValue
            case .openFoodFacts: openFoodFacts = newValue
            }
        }
    }
}
