/// The USDA FoodData Central `foods/search` response, limited to the fields CalTracker uses.
nonisolated struct USDASearchResponse: Decodable, Sendable {
    /// The matching foods.
    let foods: [Food]

    private enum CodingKeys: String, CodingKey {
        case foods
    }

    /// Creates a response from already-decoded foods.
    init(foods: [Food]) {
        self.foods = foods
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        foods = try container.decodeIfPresent([Food].self, forKey: .foods) ?? []
    }

    /// One food in the search results.
    struct Food: Decodable, Sendable {
        /// The FoodData Central identifier.
        let fdcId: Int

        /// The food's name, sent by the API as `description`.
        let name: String?

        /// The brand owner, present only for branded foods.
        let brandOwner: String?

        /// Nutrient amounts per 100 g.
        let foodNutrients: [FoodNutrient]

        private enum CodingKeys: String, CodingKey {
            case fdcId
            case name = "description"
            case brandOwner
            case foodNutrients
        }

        /// Creates a food from already-decoded values.
        init(fdcId: Int, name: String?, brandOwner: String?, foodNutrients: [FoodNutrient]) {
            self.fdcId = fdcId
            self.name = name
            self.brandOwner = brandOwner
            self.foodNutrients = foodNutrients
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            fdcId = try container.decode(Int.self, forKey: .fdcId)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            brandOwner = try container.decodeIfPresent(String.self, forKey: .brandOwner)
            foodNutrients = try container.decodeIfPresent([FoodNutrient].self, forKey: .foodNutrients) ?? []
        }
    }

    /// One nutrient amount for a food.
    struct FoodNutrient: Decodable, Sendable {
        /// The legacy nutrient number, such as "208" for energy in kcal.
        let nutrientNumber: String?

        /// The unit, such as "KCAL", "G", "MG", "UG" or "IU".
        let unitName: String?

        /// The amount per 100 g, in `unitName`.
        let value: Double?
    }
}
