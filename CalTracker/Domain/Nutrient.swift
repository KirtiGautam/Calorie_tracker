import Foundation

/// A nutrient CalTracker tracks, with its display metadata and storage location.
nonisolated enum Nutrient: String, CaseIterable, Identifiable, Codable, Sendable {
    case energy
    case protein
    case carbohydrates
    case fat
    case fiber
    case sugar
    case saturatedFat
    case cholesterol
    case sodium
    case potassium
    case calcium
    case iron
    case magnesium
    case zinc
    case vitaminC
    case vitaminA
    case vitaminD
    case vitaminB12
    case folate

    /// The headline macros, in display order.
    static let macros = allCases.filter { $0.group == .macro }

    /// The micronutrients, in display order.
    static let micros = allCases.filter { $0.group == .micro }

    /// The stable identity of the nutrient.
    var id: Self { self }

    /// The localized name shown in the interface.
    var title: LocalizedStringResource {
        switch self {
        case .energy: .nutrientEnergy
        case .protein: .nutrientProtein
        case .carbohydrates: .nutrientCarbohydrates
        case .fat: .nutrientFat
        case .fiber: .nutrientFiber
        case .sugar: .nutrientSugar
        case .saturatedFat: .nutrientSaturatedFat
        case .cholesterol: .nutrientCholesterol
        case .sodium: .nutrientSodium
        case .potassium: .nutrientPotassium
        case .calcium: .nutrientCalcium
        case .iron: .nutrientIron
        case .magnesium: .nutrientMagnesium
        case .zinc: .nutrientZinc
        case .vitaminC: .nutrientVitaminC
        case .vitaminA: .nutrientVitaminA
        case .vitaminD: .nutrientVitaminD
        case .vitaminB12: .nutrientVitaminB12
        case .folate: .nutrientFolate
        }
    }

    /// The unit amounts of this nutrient are stored and shown in.
    var unit: NutrientUnit {
        switch self {
        case .energy: .kilocalories
        case .protein, .carbohydrates, .fat, .fiber, .sugar, .saturatedFat: .grams
        case .cholesterol, .sodium, .potassium, .calcium, .iron, .magnesium, .zinc, .vitaminC: .milligrams
        case .vitaminA, .vitaminD, .vitaminB12, .folate: .micrograms
        }
    }

    /// The per-100 g amounts that can be real, in `unit`.
    ///
    /// No food has more than 100 g of one nutrient per 100 g, and pure fat is about 900 kcal per 100 g.
    var plausibleAmountsPer100g: ClosedRange<Double> {
        unit == .kilocalories ? 0...900 : 0...(100 * unit.perGram)
    }

    /// Returns `amount` when it's a real per-100 g amount of this nutrient, or `nil` when it's negative, non-finite or too large.
    func plausibleAmountPer100g(_ amount: Double) -> Double? {
        plausibleAmountsPer100g.contains(amount) ? amount : nil
    }

    /// Whether the nutrient is a macro or a micronutrient.
    var group: NutrientGroup {
        switch self {
        case .energy, .protein, .carbohydrates, .fat: .macro
        default: .micro
        }
    }

    /// The property of `NutrientProfile` that stores this nutrient.
    var keyPath: WritableKeyPath<NutrientProfile, Double?> {
        switch self {
        case .energy: \.energy
        case .protein: \.protein
        case .carbohydrates: \.carbohydrates
        case .fat: \.fat
        case .fiber: \.fiber
        case .sugar: \.sugar
        case .saturatedFat: \.saturatedFat
        case .cholesterol: \.cholesterol
        case .sodium: \.sodium
        case .potassium: \.potassium
        case .calcium: \.calcium
        case .iron: \.iron
        case .magnesium: \.magnesium
        case .zinc: \.zinc
        case .vitaminC: \.vitaminC
        case .vitaminA: \.vitaminA
        case .vitaminD: \.vitaminD
        case .vitaminB12: \.vitaminB12
        case .folate: \.folate
        }
    }
}
