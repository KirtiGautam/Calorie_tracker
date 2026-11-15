import Foundation
import SwiftData

/// Keeps custom foods in SwiftData, saving explicitly after every change.
final class CustomFoodStore: CustomFoodStoring {
    private let modelContext: ModelContext
    private let now: () -> Date

    /// Creates a store that writes through `modelContext`, stamping new foods with `now`.
    init(modelContext: ModelContext, now: @escaping () -> Date = { .now }) {
        self.modelContext = modelContext
        self.now = now
    }

    func save(_ record: CustomFoodRecord) throws {
        modelContext.insert(CustomFood(record: record, createdAt: now()))
        try modelContext.save()
    }

    func foods(matching query: String) throws -> [CustomFoodRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var descriptor = FetchDescriptor<CustomFood>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse), SortDescriptor(\.name)]
        )
        if trimmed.isEmpty == false {
            descriptor.predicate = #Predicate { $0.name.localizedStandardContains(trimmed) }
        }
        return try modelContext.fetch(descriptor).map(\.record)
    }

    func delete(id: String) throws {
        let doomed = try modelContext.fetch(FetchDescriptor<CustomFood>(predicate: #Predicate { $0.foodID == id }))
        for food in doomed {
            modelContext.delete(food)
        }
        try modelContext.save()
    }
}
