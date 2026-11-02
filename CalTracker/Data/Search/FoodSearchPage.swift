/// One page of foods from a single provider.
nonisolated struct FoodSearchPage: Sendable {
    /// The usable foods on this page, in the provider's ranking order.
    var foods: [FoodItem]

    /// Whether the provider has another page after this one.
    var hasMore = false

    /// The most common brands for the query and filters. Only Open Food Facts fills it, and only on page 1.
    var brands: [BrandOption] = []
}
