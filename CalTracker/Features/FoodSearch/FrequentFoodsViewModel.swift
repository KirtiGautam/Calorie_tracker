import Foundation
import Observation

/// Loads the foods the person logs most often and logs one again at its last amount.
@Observable
final class FrequentFoodsViewModel {
    /// The foods to offer, most frequent first.
    private(set) var frequentFoods: [FrequentFood] = []

    /// Why the foods couldn't be loaded, or `nil` when they loaded or haven't been asked for.
    private(set) var loadFailure: LocalizedStringResource?

    /// Whether there's anything to show: some foods, or why they couldn't be loaded.
    var hasContent: Bool {
        frequentFoods.isEmpty == false || loadFailure != nil
    }

    @ObservationIgnored private let history: any FoodHistory
    @ObservationIgnored private let foodLog: any FoodLogging

    /// Creates a view model that reads the log from `history` and writes quick adds through `foodLog`.
    init(history: any FoodHistory, foodLog: any FoodLogging) {
        self.history = history
        self.foodLog = foodLog
    }

    /// Ranks the foods logged in the lookback window that ends at `now`, with days defined by `calendar`.
    func load(now: Date, calendar: Calendar) {
        do {
            let start = FrequentFoodRanking.windowStart(endingAt: now, calendar: calendar)
            frequentFoods = FrequentFoodRanking.rank(try history.records(loggedSince: start), calendar: calendar)
            loadFailure = nil
        } catch {
            frequentFoods = []
            loadFailure = userMessage(for: error)
        }
    }

    /// Logs `frequentFood` again at the amount logged last time.
    ///
    /// - Returns: What was logged, carrying the saved entry so the confirmation can offer Undo.
    /// - Throws: The store's error when the food can't be saved.
    func quickLog(_ frequentFood: FrequentFood) throws -> LoggedFood {
        let entry = try foodLog.log(frequentFood.food, grams: frequentFood.grams)
        return LoggedFood(name: frequentFood.food.name, grams: frequentFood.grams, undoableEntry: entry)
    }
}
