@testable import CalTracker

extension CustomFoodRecord {
    /// Creates a deterministic custom food for tests.
    static func fixture(
        id: String = "cus-1",
        name: String = "Grandma's dal",
        per100g: NutrientProfile = NutrientProfile(energy: 120, protein: 6, carbohydrates: 15, fat: 4),
        servingGrams: Double = 350
    ) -> CustomFoodRecord {
        CustomFoodRecord(
            food: FoodItem(id: id, name: name, brand: nil, source: .custom, per100g: per100g),
            servingGrams: servingGrams
        )
    }
}
