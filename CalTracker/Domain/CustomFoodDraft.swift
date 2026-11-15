import Foundation

/// A custom food as the person types it: nutrient amounts for any weight, each in a unit of their choosing.
///
/// `per100g()` standardizes it into the app's format. Amounts are converted to each nutrient's `Nutrient.unit` and
/// scaled to 100 g, blank energy is calculated from the macros, and amounts no food could have are refused.
nonisolated struct CustomFoodDraft: Hashable, Sendable {
    /// The weight the values are for when the person doesn't change it, which matches most nutrition labels.
    static let defaultReferenceGrams = 100.0

    /// How far protein, carbohydrates and fat may add up past 100 g per 100 g, for labels that round each one up.
    static let macroRoundingAllowance = 0.5

    /// The energy in one gram of protein, carbohydrates and fat, in kcal (the Atwater general factors).
    static let kilocaloriesPerGram: [Nutrient: Double] = [.protein: 4, .carbohydrates: 4, .fat: 9]

    /// The food's name as typed.
    var name: String

    /// The weight the amounts are for, in grams, or `nil` while the field is empty.
    var referenceGrams: Double?

    /// The typed amounts, each in the unit in `units`. A nutrient without one is unknown.
    private var amounts: [Nutrient: Double] = [:]

    /// The units the person picked. A nutrient without one uses its stored unit.
    private var units: [Nutrient: NutrientEntryUnit] = [:]

    /// Creates an empty draft named `name`, for values per `referenceGrams`.
    init(name: String = "", referenceGrams: Double? = defaultReferenceGrams) {
        self.name = name
        self.referenceGrams = referenceGrams
    }

    /// Accesses the typed amount of a nutrient, in `self[unitOf: nutrient]`, or `nil` when it's blank.
    subscript(nutrient: Nutrient) -> Double? {
        get { amounts[nutrient] }
        set { amounts[nutrient] = newValue }
    }

    /// Accesses the unit a nutrient's amount is typed in. Units the nutrient can't be measured in are ignored.
    subscript(unitOf nutrient: Nutrient) -> NutrientEntryUnit {
        get { units[nutrient] ?? NutrientEntryUnit(nutrient.unit) }
        set {
            guard nutrient.entryUnits.contains(newValue) else { return }
            units[nutrient] = newValue
        }
    }

    /// The name without surrounding whitespace.
    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether any nutrient has an amount.
    var hasAmounts: Bool {
        amounts.isEmpty == false
    }

    /// Returns the nutrients for 100 g of the food, in each nutrient's `Nutrient.unit`.
    ///
    /// Blank nutrients stay unknown, except energy, which is calculated from protein, carbohydrates and fat when all
    /// three are filled in.
    ///
    /// - Throws: `CustomFoodError.invalidReferenceAmount`, `.implausibleAmount`, `.macrosExceedWeight` or
    ///   `.missingEnergy`, checked in that order.
    func per100g() throws -> NutrientProfile {
        guard let referenceGrams, referenceGrams > 0, referenceGrams.isFinite else {
            throw CustomFoodError.invalidReferenceAmount
        }

        var profile = NutrientProfile()
        for nutrient in Nutrient.allCases {
            guard let amount = amounts[nutrient] else { continue }
            guard let converted = self[unitOf: nutrient].amount(amount, of: nutrient),
                  let scaled = nutrient.plausibleAmountPer100g(converted * 100 / referenceGrams)
            else {
                throw CustomFoodError.implausibleAmount(nutrient)
            }
            profile[nutrient] = scaled
        }

        let macroGrams = [Nutrient.protein, .carbohydrates, .fat].compactMap { profile[$0] }.reduce(0, +)
        guard macroGrams <= 100 + Self.macroRoundingAllowance else { throw CustomFoodError.macrosExceedWeight }

        if profile.energy == nil {
            profile.energy = try Self.energy(from: profile)
        }
        return profile
    }

    /// Standardizes the draft into a food that can be saved and logged.
    ///
    /// - Parameter code: Makes the food's ID unique. A new one by default.
    /// - Throws: `CustomFoodError.missingName`, or any error `per100g()` throws.
    func standardized(code: UUID = UUID()) throws -> CustomFoodRecord {
        guard trimmedName.isEmpty == false else { throw CustomFoodError.missingName }
        let per100g = try per100g()
        guard let referenceGrams else { throw CustomFoodError.invalidReferenceAmount }

        // 32 hex digits, which the server's food ID rule (letters and digits, at most 64 in all) accepts.
        let id = FoodSource.custom.foodID(code: code.uuidString.replacing("-", with: "").lowercased())
        return CustomFoodRecord(
            food: FoodItem(id: id, name: trimmedName, brand: nil, source: .custom, per100g: per100g),
            servingGrams: referenceGrams
        )
    }

    /// Calculates the energy in `profile` from its protein, carbohydrates and fat.
    ///
    /// - Throws: `CustomFoodError.missingEnergy` when one of the three is unknown.
    private static func energy(from profile: NutrientProfile) throws -> Double {
        var energy = 0.0
        for (nutrient, kilocalories) in kilocaloriesPerGram {
            guard let grams = profile[nutrient] else { throw CustomFoodError.missingEnergy }
            energy += grams * kilocalories
        }
        guard let plausible = Nutrient.energy.plausibleAmountPer100g(energy) else {
            throw CustomFoodError.implausibleAmount(.energy)
        }
        return plausible
    }
}
