import Foundation

/// A logged food as plain values, for logic that can't see SwiftData.
nonisolated struct FoodLogRecord: Hashable, Sendable {
    /// The food as it was when it was logged.
    let food: FoodItem

    /// The amount eaten, in grams.
    let grams: Double

    /// When the food was logged.
    let loggedAt: Date
}
