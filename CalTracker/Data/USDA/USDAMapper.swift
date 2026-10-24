import Foundation

/// Converts USDA FoodData Central DTOs into `FoodItem`s.
nonisolated enum USDAMapper {
    /// Micrograms of vitamin D (cholecalciferol) per International Unit.
    static let vitaminDMicrogramsPerIU = 0.025

    /// Returns the foods in `response`, dropping any without a name.
    static func foodItems(from response: USDASearchResponse) -> [FoodItem] {
        response.foods.compactMap(foodItem(from:))
    }

    /// Returns a food for `food`, or `nil` when it has no name.
    static func foodItem(from food: USDASearchResponse.Food) -> FoodItem? {
        guard let name = food.name?.trimmingCharacters(in: .whitespacesAndNewlines), name.isEmpty == false else {
            return nil
        }

        let brand = food.brandOwner?.trimmingCharacters(in: .whitespacesAndNewlines)
        return FoodItem(
            id: "usda-\(food.fdcId)",
            name: name,
            brand: brand?.isEmpty == false ? brand : nil,
            source: .usda,
            per100g: profile(from: food.foodNutrients)
        )
    }

    /// Builds a per-100 g profile, taking the first usable nutrient number for each nutrient.
    ///
    /// A number whose amount is negative or impossibly large is skipped in favor of the next one.
    static func profile(from foodNutrients: [USDASearchResponse.FoodNutrient]) -> NutrientProfile {
        var byNumber: [String: USDASearchResponse.FoodNutrient] = [:]
        for foodNutrient in foodNutrients {
            if let number = foodNutrient.nutrientNumber, foodNutrient.value != nil, byNumber[number] == nil {
                byNumber[number] = foodNutrient
            }
        }

        var profile = NutrientProfile()
        for nutrient in Nutrient.allCases {
            profile[nutrient] = nutrientNumbers(for: nutrient).lazy
                .compactMap { byNumber[$0] }
                .compactMap { convert($0, to: nutrient) }
                .compactMap(nutrient.plausibleAmountPer100g)
                .first
        }
        return profile
    }

    /// The USDA nutrient numbers for `nutrient`, most preferred first.
    static func nutrientNumbers(for nutrient: Nutrient) -> [String] {
        switch nutrient {
        // 957 and 958 are the Atwater general and specific energy values that Foundation foods use instead of 208.
        case .energy: ["208", "957", "958"]
        case .protein: ["203"]
        case .carbohydrates: ["205"]
        case .fat: ["204"]
        case .fiber: ["291"]
        case .sugar: ["269"]
        case .saturatedFat: ["606"]
        case .cholesterol: ["601"]
        case .sodium: ["307"]
        case .potassium: ["306"]
        case .calcium: ["301"]
        case .iron: ["303"]
        case .magnesium: ["304"]
        case .zinc: ["309"]
        case .vitaminC: ["401"]
        case .vitaminA: ["320"]
        // 324 is vitamin D in IU, converted to µg when 328 is missing.
        case .vitaminD: ["328", "324"]
        case .vitaminB12: ["418"]
        // 435 is folate as dietary folate equivalents, used when total folate is missing.
        case .folate: ["417", "435"]
        }
    }

    /// Converts a USDA amount into `nutrient`'s display unit, or returns `nil` when the unit can't be converted.
    static func convert(_ foodNutrient: USDASearchResponse.FoodNutrient, to nutrient: Nutrient) -> Double? {
        // The micro sign and Greek mu become "u" first, because uppercasing turns either into a capital mu.
        guard let value = foodNutrient.value, let unitName = foodNutrient.unitName?.replacing(/[µμ]/, with: "u").uppercased() else {
            return nil
        }

        if nutrient.unit == .kilocalories {
            return switch unitName {
            case "KCAL": value
            case "KJ": value / OFFMapper.kilojoulesPerKilocalorie
            default: nil
            }
        }

        if unitName == "IU" {
            // Only vitamin D has a fixed IU conversion. Vitamin A IU depends on the source compound.
            return nutrient == .vitaminD ? value * vitaminDMicrogramsPerIU : nil
        }

        let sourceUnitsPerGram: Double? = switch unitName {
        case "G": NutrientUnit.grams.perGram
        case "MG": NutrientUnit.milligrams.perGram
        case "UG", "MCG": NutrientUnit.micrograms.perGram
        default: nil
        }
        // One combined factor keeps same-unit values exact (12.5 µg stays 12.5, not 12.499999999999998).
        return sourceUnitsPerGram.map { value * (nutrient.unit.perGram / $0) }
    }
}
