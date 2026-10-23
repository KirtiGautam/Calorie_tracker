import Foundation

/// Converts Open Food Facts DTOs into `FoodItem`s.
nonisolated enum OFFMapper {
    /// Kilojoules per kilocalorie, used when a product only reports energy in kJ.
    static let kilojoulesPerKilocalorie = 4.184

    /// Returns the usable foods in `response`, dropping products without a name or energy value.
    static func foodItems(from response: OFFSearchResponse) -> [FoodItem] {
        response.products.compactMap(foodItem(from:))
    }

    /// Returns a food for `product`, or `nil` when it lacks a code, a name or an energy value.
    static func foodItem(from product: OFFSearchResponse.Product) -> FoodItem? {
        guard
            let code = product.code?.trimmingCharacters(in: .whitespaces), code.isEmpty == false,
            let name = product.productName?.trimmingCharacters(in: .whitespacesAndNewlines), name.isEmpty == false
        else {
            return nil
        }

        let profile = profile(from: product.nutriments)
        guard profile.energy != nil else { return nil }

        return FoodItem(
            id: "off-\(code)",
            name: name,
            brand: primaryBrand(from: product.brands),
            source: .openFoodFacts,
            per100g: profile
        )
    }

    /// Builds a per-100 g profile, converting OFF's gram values into each nutrient's display unit.
    static func profile(from nutriments: OFFSearchResponse.Nutriments) -> NutrientProfile {
        var profile = NutrientProfile()
        for nutrient in Nutrient.allCases {
            if let grams = nutriments.values[fieldName(for: nutrient)] {
                profile[nutrient] = grams * nutrient.unit.perGram
            }
        }

        // `energy_100g` is always in kJ, so it's only a fallback when kcal is missing.
        if profile.energy == nil, let kilojoules = nutriments.values["energy_100g"] {
            profile.energy = kilojoules / kilojoulesPerKilocalorie
        }
        return profile
    }

    /// The OFF nutriment field that holds `nutrient` per 100 g.
    static func fieldName(for nutrient: Nutrient) -> String {
        switch nutrient {
        case .energy: "energy-kcal_100g"
        case .protein: "proteins_100g"
        case .carbohydrates: "carbohydrates_100g"
        case .fat: "fat_100g"
        case .fiber: "fiber_100g"
        case .sugar: "sugars_100g"
        case .saturatedFat: "saturated-fat_100g"
        case .cholesterol: "cholesterol_100g"
        case .sodium: "sodium_100g"
        case .potassium: "potassium_100g"
        case .calcium: "calcium_100g"
        case .iron: "iron_100g"
        case .magnesium: "magnesium_100g"
        case .zinc: "zinc_100g"
        case .vitaminC: "vitamin-c_100g"
        case .vitaminA: "vitamin-a_100g"
        case .vitaminD: "vitamin-d_100g"
        case .vitaminB12: "vitamin-b12_100g"
        case .folate: "folates_100g"
        }
    }

    /// Returns the first brand in OFF's comma-separated `brands` field.
    private static func primaryBrand(from brands: String?) -> String? {
        let first = brands?
            .split(separator: ",")
            .first?
            .trimmingCharacters(in: .whitespaces)
        guard let first, first.isEmpty == false else { return nil }
        return first
    }
}
