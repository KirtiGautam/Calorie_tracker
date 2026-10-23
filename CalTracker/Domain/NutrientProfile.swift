/// Nutrient amounts for a quantity of food, each in its `Nutrient.unit`.
///
/// Every nutrient is a named optional so SwiftData can store the profile as a
/// composite attribute. `nil` means the source didn't report that nutrient.
nonisolated struct NutrientProfile: Codable, Hashable, Sendable {
    var energy: Double?
    var protein: Double?
    var carbohydrates: Double?
    var fat: Double?
    var fiber: Double?
    var sugar: Double?
    var saturatedFat: Double?
    var cholesterol: Double?
    var sodium: Double?
    var potassium: Double?
    var calcium: Double?
    var iron: Double?
    var magnesium: Double?
    var zinc: Double?
    var vitaminC: Double?
    var vitaminA: Double?
    var vitaminD: Double?
    var vitaminB12: Double?
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
