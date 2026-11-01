import Foundation
import SwiftData

extension SchemaV1 {
    /// A logged food as version 1 stored it, frozen so the migration to version 2 can read old stores.
    ///
    /// Don't change this type. Add a new schema version instead.
    @Model
    final class FoodLogEntry {
        #Index<FoodLogEntry>([\.loggedAt])

        /// The `FoodItem.id` the entry was logged from.
        var foodID: String = ""

        /// The food's name at the time it was logged.
        var name: String = ""

        /// The food's brand at the time it was logged.
        var brand: String?

        /// The database the food came from.
        var source: FoodSource = FoodSource.usda

        /// The amount eaten, in grams.
        var grams: Double = 0

        /// The food's nutrients per 100 g.
        var per100g: NutrientProfile = NutrientProfile()

        /// When the food was logged.
        var loggedAt: Date = Date.now

        /// Creates an entry for `grams` of `food` logged at `loggedAt`.
        init(food: FoodItem, grams: Double, loggedAt: Date) {
            foodID = food.id
            name = food.name
            brand = food.brand
            source = food.source
            self.grams = grams
            per100g = food.per100g
            self.loggedAt = loggedAt
        }
    }
}
