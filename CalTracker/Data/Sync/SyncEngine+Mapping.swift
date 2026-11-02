import Foundation

/// The server's limits, and the conversions between local entries and the items the server stores.
extension SyncEngine {
    /// The largest amount the server accepts for one entry, in grams.
    static let maxGrams = 5_000.0

    /// The longest food ID the server accepts.
    static let maxFoodIDLength = 64

    /// The longest name the server accepts, in Unicode scalars, because it counts code points rather than characters.
    static let maxNameLength = 500

    /// The most foods the server keeps for one day, counting every device's foods.
    static let maxFoodsPerDay = 200

    /// Whether the server accepts `entry`: a USDA or Open Food Facts food ID it allows and an amount it allows.
    static func isSyncable(_ entry: FoodLogEntry) -> Bool {
        FoodSource(foodID: entry.foodID)?.code(fromFoodID: entry.foodID)?.wholeMatch(of: /[A-Za-z0-9]+/) != nil
            && entry.foodID.unicodeScalars.count <= maxFoodIDLength
            && entry.grams > 0
            && entry.grams <= maxGrams
    }

    /// The item the server stores for `entry`, with the macros for the amount eaten.
    static func loggedFood(for entry: FoodLogEntry, id: UUID) -> GramwiseLoggedFood {
        let name = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let nutrients = entry.nutrients
        return GramwiseLoggedFood(
            entryID: id,
            foodID: entry.foodID,
            name: name.isEmpty ? entry.foodID : String(String.UnicodeScalarView(name.unicodeScalars.prefix(maxNameLength))),
            grams: entry.grams,
            loggedAt: entry.loggedAt,
            energyKcal: nutrients.energy,
            proteinG: nutrients.protein,
            carbsG: nutrients.carbohydrates,
            fatG: nutrients.fat
        )
    }

    /// Rebuilds the food for a restored entry.
    ///
    /// Micronutrients come from the provider's current data when the lookup found it. The macros always come from
    /// the logged item, scaled back to 100 g, so the day's totals match what was logged.
    static func restoredFood(from food: GramwiseLoggedFood, provider: FoodItem?) -> FoodItem {
        var per100g = provider?.per100g ?? NutrientProfile()
        let factor = food.grams > 0 ? 100 / food.grams : 0
        per100g.energy = food.energyKcal.map { $0 * factor }
        per100g.protein = food.proteinG.map { $0 * factor }
        per100g.carbohydrates = food.carbsG.map { $0 * factor }
        per100g.fat = food.fatG.map { $0 * factor }

        return FoodItem(
            id: food.foodID,
            name: food.name,
            brand: provider?.brand,
            source: provider?.source ?? FoodSource(foodID: food.foodID) ?? .usda,
            per100g: per100g
        )
    }
}
