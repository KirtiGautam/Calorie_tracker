/// Reasons daily targets can't be saved.
nonisolated enum TargetsError: Error, Equatable, Sendable {
    /// A target isn't blank or a positive, finite amount.
    case invalidTarget
}
