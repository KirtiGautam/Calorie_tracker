/// One food from the USDA FoodData Central `foods` endpoint in the abridged format, limited to the fields CalTracker uses.
nonisolated struct USDAFoodDetail: Decodable, Sendable {
    /// The FoodData Central identifier.
    let fdcId: Int

    /// The food's name, sent by the API as `description`.
    let name: String?

    /// The brand owner, present only for branded foods.
    let brandOwner: String?

    /// Nutrient amounts per 100 g.
    let foodNutrients: [Nutrient]

    private enum CodingKeys: String, CodingKey {
        case fdcId
        case name = "description"
        case brandOwner
        case foodNutrients
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fdcId = try container.decode(Int.self, forKey: .fdcId)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        brandOwner = try container.decodeIfPresent(String.self, forKey: .brandOwner)
        foodNutrients = try container.decodeIfPresent([Nutrient].self, forKey: .foodNutrients) ?? []
    }

    /// The same food in the search response's shape, so `USDAMapper` can map it.
    var searchFood: USDASearchResponse.Food {
        USDASearchResponse.Food(
            fdcId: fdcId,
            name: name,
            brandOwner: brandOwner,
            foodNutrients: foodNutrients.map { nutrient in
                USDASearchResponse.FoodNutrient(nutrientNumber: nutrient.number, unitName: nutrient.unitName, value: nutrient.amount)
            }
        )
    }

    /// One nutrient amount in the abridged format.
    struct Nutrient: Decodable, Sendable {
        /// The legacy nutrient number, such as "208" for energy in kcal.
        let number: String?

        /// The unit, such as "KCAL", "G", "MG", "UG" or "IU".
        let unitName: String?

        /// The amount per 100 g, in `unitName`.
        let amount: Double?
    }
}
