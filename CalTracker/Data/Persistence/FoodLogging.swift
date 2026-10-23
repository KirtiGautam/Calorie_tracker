/// Records and removes logged foods.
protocol FoodLogging {
    /// Logs `grams` of `food` at the current time.
    func log(_ food: FoodItem, grams: Double) throws

    /// Removes `entry` from the log.
    func delete(_ entry: FoodLogEntry) throws
}
