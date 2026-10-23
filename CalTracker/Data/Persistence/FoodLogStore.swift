import Foundation
import SwiftData

/// Writes food log entries to SwiftData, saving explicitly after every change.
final class FoodLogStore: FoodLogging {
    private let modelContext: ModelContext

    /// Creates a store that writes through `modelContext`.
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func log(_ food: FoodItem, grams: Double) throws {
        try log(food, grams: grams, loggedAt: .now)
    }

    /// Logs `grams` of `food` at `loggedAt`.
    func log(_ food: FoodItem, grams: Double, loggedAt: Date) throws {
        guard grams > 0, grams.isFinite else { throw LogFoodError.invalidAmount }
        modelContext.insert(FoodLogEntry(food: food, grams: grams, loggedAt: loggedAt))
        try modelContext.save()
    }

    func delete(_ entry: FoodLogEntry) throws {
        modelContext.delete(entry)
        try modelContext.save()
    }
}
