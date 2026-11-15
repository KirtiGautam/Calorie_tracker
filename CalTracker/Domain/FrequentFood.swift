/// A food the person logs often, with the amount they logged most recently.
nonisolated struct FrequentFood: Identifiable, Hashable, Sendable {
    /// The food as it was the last time it was logged.
    let food: FoodItem

    /// The amount logged most recently, in grams, which quick add logs again.
    let grams: Double

    /// The food's ID, since each food appears once.
    var id: String {
        food.id
    }

    /// The nutrients in `grams` of the food.
    var nutrients: NutrientProfile {
        food.per100g.scaled(byGrams: grams)
    }
}
