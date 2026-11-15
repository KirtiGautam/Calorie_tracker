import Foundation
import SwiftData

/// The current version of a food the person entered themselves.
typealias CustomFood = SchemaV3.CustomFood

extension SchemaV3 {
    /// A food the person entered from a label or a recipe, kept so they can log it again.
    ///
    /// Log entries copy its name and nutrients, so deleting it leaves the log as it was.
    @Model
    final class CustomFood {
        /// The food's `cus-` ID, which log entries record as their `FoodLogEntry.foodID`.
        var foodID: String = ""

        /// The name the person gave it.
        var name: String = ""

        /// The nutrients in 100 g, standardized from what the person typed.
        var per100g: NutrientProfile = NutrientProfile()

        /// The weight the person entered the values for, in grams, where the log sheet starts.
        var servingGrams: Double = 100

        /// When it was saved, so the newest foods are listed first.
        var createdAt: Date = Date.now

        /// Creates the stored copy of `record`, saved at `createdAt`.
        init(record: CustomFoodRecord, createdAt: Date) {
            foodID = record.id
            name = record.food.name
            per100g = record.food.per100g
            servingGrams = record.servingGrams
            self.createdAt = createdAt
        }

        /// The food as plain values.
        var record: CustomFoodRecord {
            CustomFoodRecord(
                food: FoodItem(id: foodID, name: name, brand: nil, source: .custom, per100g: per100g),
                servingGrams: servingGrams
            )
        }
    }
}
