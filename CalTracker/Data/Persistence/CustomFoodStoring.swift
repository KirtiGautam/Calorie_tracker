/// Keeps the foods the person entered themselves.
protocol CustomFoodStoring {
    /// Saves `record`.
    func save(_ record: CustomFoodRecord) throws

    /// Returns the saved foods whose names contain `query`, ignoring case and accents, newest first.
    ///
    /// A blank query returns every saved food.
    func foods(matching query: String) throws -> [CustomFoodRecord]

    /// Removes the food with the ID `id`. Entries already logged from it stay in the log.
    func delete(id: String) throws
}
