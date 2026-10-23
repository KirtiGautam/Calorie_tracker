@testable import CalTracker

extension FoodItem {
    /// Creates a deterministic food for tests.
    static func fixture(
        id: String = "usda-1",
        name: String = "Test Food",
        brand: String? = nil,
        source: FoodSource = .usda,
        per100g: NutrientProfile = NutrientProfile(energy: 200, protein: 10, carbohydrates: 30, fat: 5)
    ) -> FoodItem {
        FoodItem(id: id, name: name, brand: brand, source: source, per100g: per100g)
    }
}
