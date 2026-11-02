extension SchemaV1 {
    /// Nutrient amounts per 100 g as version 1 stored them, each in its `Nutrient.unit`.
    ///
    /// SwiftData stores every property as its own column, so adding a nutrient to the app's `NutrientProfile` changes
    /// the stored layout. This frozen copy keeps version 1 matching the stores it wrote. Don't change this type.
    nonisolated struct NutrientProfile: Codable, Hashable, Sendable {
        /// Energy, in kcal.
        var energy: Double?

        /// Protein, in grams.
        var protein: Double?

        /// Carbohydrates, in grams.
        var carbohydrates: Double?

        /// Fat, in grams.
        var fat: Double?

        /// Fiber, in grams.
        var fiber: Double?

        /// Sugar, in grams.
        var sugar: Double?

        /// Saturated fat, in grams.
        var saturatedFat: Double?

        /// Cholesterol, in milligrams.
        var cholesterol: Double?

        /// Sodium, in milligrams.
        var sodium: Double?

        /// Potassium, in milligrams.
        var potassium: Double?

        /// Calcium, in milligrams.
        var calcium: Double?

        /// Iron, in milligrams.
        var iron: Double?

        /// Magnesium, in milligrams.
        var magnesium: Double?

        /// Zinc, in milligrams.
        var zinc: Double?

        /// Vitamin C, in milligrams.
        var vitaminC: Double?

        /// Vitamin A, in micrograms.
        var vitaminA: Double?

        /// Vitamin D, in micrograms.
        var vitaminD: Double?

        /// Vitamin B12, in micrograms.
        var vitaminB12: Double?

        /// Folate, in micrograms.
        var folate: Double?

        /// Creates an empty profile, with every nutrient unknown.
        init() {}

        /// Copies the version 1 nutrients from the app's current `profile`.
        init(_ profile: CalTracker.NutrientProfile) {
            energy = profile.energy
            protein = profile.protein
            carbohydrates = profile.carbohydrates
            fat = profile.fat
            fiber = profile.fiber
            sugar = profile.sugar
            saturatedFat = profile.saturatedFat
            cholesterol = profile.cholesterol
            sodium = profile.sodium
            potassium = profile.potassium
            calcium = profile.calcium
            iron = profile.iron
            magnesium = profile.magnesium
            zinc = profile.zinc
            vitaminC = profile.vitaminC
            vitaminA = profile.vitaminA
            vitaminD = profile.vitaminD
            vitaminB12 = profile.vitaminB12
            folate = profile.folate
        }
    }
}
