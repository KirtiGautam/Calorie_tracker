/// Where a day's total sits relative to its target.
nonisolated enum TargetStatus: Hashable, Sendable {
    /// More than the tolerance below the target.
    case deficit

    /// Within the tolerance of the target.
    case onTarget

    /// More than the tolerance above the target.
    case surplus
}
