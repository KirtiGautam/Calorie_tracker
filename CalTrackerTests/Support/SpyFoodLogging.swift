@testable import CalTracker

/// A `FoodLogging` double that records calls and can be told to fail.
final class SpyFoodLogging: FoodLogging {
    /// The foods and amounts passed to `log(_:grams:)`, in order.
    private(set) var loggedCalls: [(food: FoodItem, grams: Double)] = []

    /// The entries passed to `delete(_:)`, in order.
    private(set) var deletedEntries: [FoodLogEntry] = []

    /// When set, every call throws this error instead of recording.
    var errorToThrow: (any Error)?

    func log(_ food: FoodItem, grams: Double) throws {
        if let errorToThrow { throw errorToThrow }
        loggedCalls.append((food, grams))
    }

    func delete(_ entry: FoodLogEntry) throws {
        if let errorToThrow { throw errorToThrow }
        deletedEntries.append(entry)
    }
}
