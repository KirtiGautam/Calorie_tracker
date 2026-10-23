extension FoodItem {
    /// A USDA whole food for SwiftUI previews.
    static let previewBanana = FoodItem(
        id: "usda-173944",
        name: "Bananas, raw",
        brand: nil,
        source: .usda,
        per100g: NutrientProfile(
            energy: 89, protein: 1.09, carbohydrates: 22.84, fat: 0.33, fiber: 2.6, sugar: 12.23,
            saturatedFat: 0.112, cholesterol: 0, sodium: 1, potassium: 358, calcium: 5, iron: 0.26,
            magnesium: 27, zinc: 0.15, vitaminC: 8.7, vitaminA: 3, vitaminD: 0, vitaminB12: 0, folate: 20
        )
    )

    /// An Open Food Facts product with sparse micronutrients, for SwiftUI previews.
    static let previewNutella = FoodItem(
        id: "off-3017620422003",
        name: "Nutella",
        brand: "Ferrero",
        source: .openFoodFacts,
        per100g: NutrientProfile(
            energy: 539, protein: 6.3, carbohydrates: 57.5, fat: 30.9, sugar: 56.3,
            saturatedFat: 10.6, sodium: 42.8
        )
    )
}
