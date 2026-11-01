import Foundation
import SwiftData

/// Writes food log entries to SwiftData, saving explicitly after every change.
final class FoodLogStore: FoodLogging {
    /// Called after every successful change, so sync can push it.
    var onChange: () -> Void

    private let modelContext: ModelContext

    /// Creates a store that writes through `modelContext` and calls `onChange` after each change.
    init(modelContext: ModelContext, onChange: @escaping () -> Void = {}) {
        self.modelContext = modelContext
        self.onChange = onChange
    }

    func log(_ food: FoodItem, grams: Double) throws {
        try log(food, grams: grams, loggedAt: .now)
    }

    /// Logs `grams` of `food` at `loggedAt`.
    func log(_ food: FoodItem, grams: Double, loggedAt: Date) throws {
        guard grams > 0, grams.isFinite else { throw LogFoodError.invalidAmount }
        modelContext.insert(FoodLogEntry(food: food, grams: grams, loggedAt: loggedAt))
        try modelContext.save()
        onChange()
    }

    /// Removes `entry`. When it was already pushed, a tombstone is saved with it, so the next sync removes it from the server too.
    func delete(_ entry: FoodLogEntry) throws {
        if let syncID = entry.syncID, let day = entry.syncedDay {
            modelContext.insert(FoodLogDeletion(syncID: syncID, day: day))
        }
        modelContext.delete(entry)
        try modelContext.save()
        onChange()
    }
}
