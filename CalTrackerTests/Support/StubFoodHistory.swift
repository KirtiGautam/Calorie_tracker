import Foundation
@testable import CalTracker

/// A `FoodHistory` that returns the records it was given, or throws, and records what it was asked for.
final class StubFoodHistory: FoodHistory {
    /// The records every call returns.
    var records: [FoodLogRecord]

    /// When set, every call throws this error instead.
    var errorToThrow: (any Error)?

    /// The window starts passed to `records(loggedSince:)`, in order.
    private(set) var requestedStarts: [Date] = []

    /// Creates a history that returns `records`.
    init(records: [FoodLogRecord] = []) {
        self.records = records
    }

    func records(loggedSince start: Date) throws -> [FoodLogRecord] {
        requestedStarts.append(start)
        if let errorToThrow { throw errorToThrow }
        return records
    }
}
