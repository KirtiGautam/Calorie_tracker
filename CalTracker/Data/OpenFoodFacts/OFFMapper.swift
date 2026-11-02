import Foundation

/// Converts Open Food Facts DTOs into `FoodItem`s.
nonisolated enum OFFMapper {
    /// Returns the usable foods in `response`, dropping products without a name or a plausible energy value.
    static func foodItems(from response: OFFSearchResponse) -> [FoodItem] {
        response.products.compactMap(foodItem(from:))
    }

    /// The facet bucket OFF uses for every brand outside the top ones. It isn't a brand, so it's skipped.
    static let otherFacetKey = "--other--"

    /// Returns the most common brands in `response`'s facets, in OFF's order.
    ///
    /// Each name is the brand as spelled by a product on this page with the same tag. When no product
    /// matches, the name is the tag with hyphens turned into spaces and capitalized.
    static func brandOptions(from response: OFFSearchResponse) -> [BrandOption] {
        var spellings: [String: String] = [:]
        for product in response.products {
            for brand in brands(from: product.brands) {
                let tag = OFFSearchQuery.tag(for: brand)
                if spellings[tag] == nil {
                    spellings[tag] = brand
                }
            }
        }

        return response.brandFacets.compactMap { item in
            guard item.key != otherFacetKey, item.key.isEmpty == false else { return nil }
            let name = spellings[item.key] ?? item.key.replacing("-", with: " ").capitalized
            return BrandOption(tag: item.key, name: name)
        }
    }

    /// Returns a food for `product`, or `nil` when it lacks a code, a name or a plausible energy value.
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
            id: FoodSource.openFoodFacts.foodID(code: code),
            name: name,
            brand: primaryBrand(from: product.brands),
            source: .openFoodFacts,
            per100g: profile
        )
    }

    /// Builds a per-100 g profile, converting OFF's gram values into each nutrient's display unit.
    ///
    /// OFF is user-contributed, so negative, non-finite and impossibly large values are treated as unknown.
    static func profile(from nutriments: OFFSearchResponse.Nutriments) -> NutrientProfile {
        var profile = NutrientProfile()
        for nutrient in Nutrient.allCases {
            if let grams = nutriments.values[fieldName(for: nutrient)] {
                profile[nutrient] = nutrient.plausibleAmountPer100g(grams * nutrient.unit.perGram)
            }
        }

        // `energy_100g` is always in kJ, so it's only a fallback when kcal is missing or implausible.
        if profile.energy == nil, let kilojoules = nutriments.values["energy_100g"] {
            profile.energy = Nutrient.energy.plausibleAmountPer100g(kilojoules / NutrientUnit.kilojoulesPerKilocalorie)
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
        self.brands(from: brands).first
    }

    /// Returns the non-empty brands in OFF's comma-separated `brands` field, in order.
    private static func brands(from brands: String?) -> [String] {
        (brands ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.isEmpty == false }
    }
}
