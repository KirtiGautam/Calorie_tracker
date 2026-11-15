import Foundation
import SwiftData

/// Writes food log entries to SwiftData, saving explicitly after every change, and reads them back.
final class FoodLogStore: FoodLogging, FoodHistory {
    /// Called after every successful change, so sync can push it.
    var onChange: () -> Void

    private let modelContext: ModelContext

    /// Creates a store that writes through `modelContext` and calls `onChange` after each change.
    init(modelContext: ModelContext, onChange: @escaping () -> Void = {}) {
        self.modelContext = modelContext
        self.onChange = onChange
    }

    @discardableResult
    func log(_ food: FoodItem, grams: Double) throws -> FoodLogEntry {
        try log(food, grams: grams, loggedAt: .now)
    }

    /// Logs `grams` of `food` at `loggedAt`.
    ///
    /// - Returns: The saved entry.
    @discardableResult
    func log(_ food: FoodItem, grams: Double, loggedAt: Date) throws -> FoodLogEntry {
        guard grams > 0, grams.isFinite else { throw LogFoodError.invalidAmount }
        let entry = FoodLogEntry(food: food, grams: grams, loggedAt: loggedAt)
        modelContext.insert(entry)
        try modelContext.save()
        onChange()
        return entry
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

    func records(loggedSince start: Date) throws -> [FoodLogRecord] {
        let descriptor = FetchDescriptor(
            predicate: FoodLogEntry.loggedSince(start),
            sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(\.record)
    }
}
