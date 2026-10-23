import Foundation
import Observation

/// Holds the amount being logged for one food and previews its nutrients.
@Observable
final class LogFoodViewModel {
    /// The quick-pick amounts, in grams.
    static let gramPresets: [Double] = [50, 100, 150, 200]

    /// The food being logged.
    let food: FoodItem

    /// The amount to log, in grams.
    var grams = 100.0

    @ObservationIgnored private let foodLog: any FoodLogging

    /// Creates a view model that logs `food` through `foodLog`.
    init(food: FoodItem, foodLog: any FoodLogging) {
        self.food = food
        self.foodLog = foodLog
    }

    /// Whether `grams` is a positive, finite amount that can be logged.
    var isValid: Bool {
        grams > 0 && grams.isFinite
    }

    /// The nutrients in `grams` of the food.
    var preview: NutrientProfile {
        food.per100g.scaled(byGrams: grams)
    }

    /// Logs the current amount.
    ///
    /// - Returns: What was logged, for the confirmation.
    /// - Throws: `LogFoodError.invalidAmount` when `isValid` is false, or the store's save error.
    func log() throws -> LoggedFood {
        guard isValid else { throw LogFoodError.invalidAmount }
        try foodLog.log(food, grams: grams)
        return LoggedFood(name: food.name, grams: grams)
    }
}
