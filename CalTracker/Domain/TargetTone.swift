/// The colour cue for a total's progress toward its target.
nonisolated enum TargetTone: Hashable, Sendable {
    /// Still short of the target.
    case caution

    /// On target, or over a target where more is fine.
    case good

    /// Over a target where more is a problem.
    case alert
}
