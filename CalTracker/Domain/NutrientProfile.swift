/// Nutrient amounts for a quantity of food, each in its `Nutrient.unit`.
///
/// Every nutrient is a named optional so SwiftData can store the profile as a
/// composite attribute. `nil` means the source didn't report that nutrient.
///
/// SwiftData stores each property as its own column, so adding a nutrient changes the stored layout of every schema
/// version that uses this type. Freeze the current version's copy and add a new schema version first (see `SchemaV2`).
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

    /// Accesses the amount of a nutrient, or `nil` when it's unknown.
    subscript(nutrient: Nutrient) -> Double? {
        get { self[keyPath: nutrient.keyPath] }
        set { self[keyPath: nutrient.keyPath] = newValue }
    }

    /// Returns the profile for `grams` of a food whose values are per 100 g.
    ///
    /// Negative or non-finite amounts are treated as 0 g. Unknown values stay unknown.
    func scaled(byGrams grams: Double) -> NutrientProfile {
        let factor = grams.isFinite ? max(grams, 0) / 100 : 0
        var result = NutrientProfile()
        for nutrient in Nutrient.allCases {
            result[nutrient] = self[nutrient].map { $0 * factor }
        }
        return result
    }

    /// Adds two profiles nutrient by nutrient.
    ///
    /// A nutrient known on only one side keeps that side's value. A nutrient unknown on both sides stays unknown.
    static func + (lhs: NutrientProfile, rhs: NutrientProfile) -> NutrientProfile {
        var result = NutrientProfile()
        for nutrient in Nutrient.allCases {
            result[nutrient] = switch (lhs[nutrient], rhs[nutrient]) {
            case let (left?, right?): left + right
            case let (left?, nil): left
            case let (nil, right?): right
            case (nil, nil): nil
            }
        }
        return result
    }
}
