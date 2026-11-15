import Foundation

/// Reads back what the person has logged.
protocol FoodHistory {
    /// Returns every entry logged at or after `start`, newest first.
    func records(loggedSince start: Date) throws -> [FoodLogRecord]
}
