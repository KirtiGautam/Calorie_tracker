/// One database that couldn't answer a search.
nonisolated struct SourceFailure: Identifiable, Sendable {
    /// The database that failed.
    let source: FoodSource

    /// Why it failed.
    let error: any Error

    /// The stable identity of the failure: its database.
    var id: FoodSource { source }
}
