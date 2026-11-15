/// A food the person entered themselves, standardized to per 100 g like every other food.
nonisolated struct CustomFoodRecord: Identifiable, Hashable, Sendable {
    /// The food, with a `cus-` ID and source `.custom`.
    let food: FoodItem

    /// The weight the person entered the values for, in grams, such as one serving. The log sheet starts at it.
    let servingGrams: Double

    /// The food's ID.
    var id: String {
        food.id
    }
}
