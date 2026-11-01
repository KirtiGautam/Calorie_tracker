/// One push: foods to add or replace, and foods to remove. At most `maxCount` of each.
nonisolated struct GramwiseLogChanges: Encodable, Hashable, Sendable {
    /// The most additions, and separately the most removals, the server accepts in one push.
    static let maxCount = 500

    /// Foods to add, or to replace when the entry ID already exists.
    let added: [GramwiseAddedFood]

    /// Foods to remove.
    let removed: [GramwiseRemovedFood]
}
