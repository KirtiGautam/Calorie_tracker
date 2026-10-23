/// Reasons a food can't be logged.
nonisolated enum LogFoodError: Error, Equatable, Sendable {
    /// The amount isn't a positive, finite number of grams.
    case invalidAmount
}
