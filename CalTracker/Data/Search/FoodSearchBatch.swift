/// The outcome of asking each source for its next page, kept separate so one failure doesn't hide the other's results.
nonisolated struct FoodSearchBatch: Sendable {
    /// USDA's page, or `nil` when USDA wasn't asked because it had no more pages.
    var usda: Result<FoodSearchPage, any Error>?

    /// Open Food Facts' page, or `nil` when it wasn't asked because it had no more pages.
    var openFoodFacts: Result<FoodSearchPage, any Error>?

    /// The outcome for `source`.
    subscript(source: FoodSource) -> Result<FoodSearchPage, any Error>? {
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
