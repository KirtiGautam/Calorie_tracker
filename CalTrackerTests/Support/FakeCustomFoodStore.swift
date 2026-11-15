import Foundation
@testable import CalTracker

/// A `CustomFoodStoring` that keeps foods in memory, matches names like the real store, and can be told to fail.
final class FakeCustomFoodStore: CustomFoodStoring {
    /// The saved foods, newest first.
    private(set) var records: [CustomFoodRecord]

    /// When set, every call throws this error instead.
    var errorToThrow: (any Error)?

    /// Creates a store holding `records`, newest first.
    init(records: [CustomFoodRecord] = []) {
        self.records = records
    }

    func save(_ record: CustomFoodRecord) throws {
        if let errorToThrow { throw errorToThrow }
        records.insert(record, at: 0)
    }

    func foods(matching query: String) throws -> [CustomFoodRecord] {
        if let errorToThrow { throw errorToThrow }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? records : records.filter { $0.food.name.localizedStandardContains(trimmed) }
    }

    func delete(id: String) throws {
        if let errorToThrow { throw errorToThrow }
        records.removeAll { $0.id == id }
    }
}
