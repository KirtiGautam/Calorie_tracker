/// A food returned by a search, with nutrients per 100 g.
nonisolated struct FoodItem: Identifiable, Hashable, Sendable {
    /// A source-prefixed identifier, such as `usda-173944` or `off-3017620422003`.
    let id: String

    /// The product or food name.
    let name: String

    /// The brand, when the source reports one.
    let brand: String?

    /// The database the food came from.
    let source: FoodSource

    /// Nutrient amounts for 100 g of the food.
    let per100g: NutrientProfile
}
