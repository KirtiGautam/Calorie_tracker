/// The USDA FoodData Central `foods/search` response, limited to the fields CalTracker uses.
nonisolated struct USDASearchResponse: Decodable, Sendable {
    /// The matching foods.
    let foods: [Food]

    /// The page these foods are on, starting at 1.
    let currentPage: Int?

    /// How many pages of results there are.
    let totalPages: Int?

    private enum CodingKeys: String, CodingKey {
        case foods
        case currentPage
        case totalPages
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        foods = try container.decodeIfPresent([Food].self, forKey: .foods) ?? []
        currentPage = try? container.decodeIfPresent(Int.self, forKey: .currentPage)
        totalPages = try? container.decodeIfPresent(Int.self, forKey: .totalPages)
    }

    /// Whether there's a page after this one. `false` when the response doesn't say.
    var hasMore: Bool {
        guard let currentPage, let totalPages else { return false }
        return currentPage < totalPages
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

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            fdcId = try container.decode(Int.self, forKey: .fdcId)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            brandOwner = try container.decodeIfPresent(String.self, forKey: .brandOwner)
            foodNutrients = try container.decodeIfPresent([FoodNutrient].self, forKey: .foodNutrients) ?? []
        }
    }

    /// One nutrient amount for a food.
    ///
    /// Search results call the number and amount `nutrientNumber` and `value`. The `foods` endpoint's abridged
    /// format calls them `number` and `amount`, and either spelling decodes.
    struct FoodNutrient: Decodable, Sendable {
        /// The legacy nutrient number, such as "208" for energy in kcal.
        let nutrientNumber: String?

        /// The unit, such as "KCAL", "G", "MG", "UG" or "IU".
        let unitName: String?

        /// The amount per 100 g, in `unitName`.
        let value: Double?
    }
}

// The decoder lives in an extension so the memberwise initializer stays available.
nonisolated extension USDASearchResponse.FoodNutrient {
    private enum CodingKeys: String, CodingKey {
        case nutrientNumber
        case unitName
        case value
        case number
        case amount
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nutrientNumber = try container.decodeIfPresent(String.self, forKey: .nutrientNumber)
            ?? container.decodeIfPresent(String.self, forKey: .number)
        unitName = try container.decodeIfPresent(String.self, forKey: .unitName)
        value = try container.decodeIfPresent(Double.self, forKey: .value)
            ?? container.decodeIfPresent(Double.self, forKey: .amount)
    }
}
