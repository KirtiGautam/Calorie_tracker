/// Records and removes logged foods.
protocol FoodLogging {
    /// Logs `grams` of `food` at the current time.
    ///
    /// - Returns: The saved entry, so the log can be undone.
    @discardableResult
    func log(_ food: FoodItem, grams: Double) throws -> FoodLogEntry

    /// Removes `entry` from the log.
    func delete(_ entry: FoodLogEntry) throws
}
