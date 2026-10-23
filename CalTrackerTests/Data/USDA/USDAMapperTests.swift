import Foundation
import Testing
@testable import CalTracker

struct USDAMapperTests {
    /// Each nutrient's primary USDA nutrient number and the unit USDA reports it in.
    nonisolated static let numberTable: [(Nutrient, String, String)] = [
        (.energy, "208", "KCAL"),
        (.protein, "203", "G"),
        (.carbohydrates, "205", "G"),
        (.fat, "204", "G"),
        (.fiber, "291", "G"),
        (.sugar, "269", "G"),
        (.saturatedFat, "606", "G"),
        (.cholesterol, "601", "MG"),
        (.sodium, "307", "MG"),
        (.potassium, "306", "MG"),
        (.calcium, "301", "MG"),
        (.iron, "303", "MG"),
        (.magnesium, "304", "MG"),
        (.zinc, "309", "MG"),
        (.vitaminC, "401", "MG"),
        (.vitaminA, "320", "UG"),
        (.vitaminD, "328", "UG"),
        (.vitaminB12, "418", "UG"),
        (.folate, "417", "UG"),
    ]

    @Test func numberTableCoversEveryNutrient() {
        #expect(Set(Self.numberTable.map(\.0)) == Set(Nutrient.allCases))
    }

    @Test(arguments: numberTable)
    func mapsEachNutrientNumber(nutrient: Nutrient, number: String, unitName: String) {
        let profile = USDAMapper.profile(from: [
            USDASearchResponse.FoodNutrient(nutrientNumber: number, unitName: unitName, value: 12.5),
        ])

        #expect(profile[nutrient] == 12.5)
    }

    @Test(arguments: [
        (Nutrient.sodium, "G", 0.5, 500.0),
        (.iron, "UG", 500, 0.5),
        (.protein, "MG", 2_500, 2.5),
        (.energy, "kJ", 418.4, 100),
        (.vitaminD, "IU", 40, 1),
    ])
    func convertsUnits(nutrient: Nutrient, unitName: String, value: Double, expected: Double) {
        let foodNutrient = USDASearchResponse.FoodNutrient(nutrientNumber: nil, unitName: unitName, value: value)

        expectApproximately(USDAMapper.convert(foodNutrient, to: nutrient), expected)
    }

    @Test(arguments: [
        (Nutrient.vitaminA, "IU"),
        (.iron, "PERCENT"),
        (.energy, "G"),
    ])
    func refusesUnitsWithoutAFixedConversion(nutrient: Nutrient, unitName: String) {
        let foodNutrient = USDASearchResponse.FoodNutrient(nutrientNumber: nil, unitName: unitName, value: 33)

        #expect(USDAMapper.convert(foodNutrient, to: nutrient) == nil)
    }

    @Test func fixtureDropsFoodsWithoutAName() throws {
        let foods = try parseFixture()

        #expect(foods.map(\.id) == ["usda-173944", "usda-2644283"])
    }

    @Test func fixtureMapsTheFullMicronutrientSet() throws {
        let banana = try #require(try parseFixture().first)

        #expect(banana.name == "Bananas, raw")
        #expect(banana.source == .usda)
        for nutrient in Nutrient.allCases {
            #expect(banana.per100g[nutrient] != nil, "\(nutrient) should be mapped")
        }
        #expect(banana.per100g.energy == 89)
        #expect(banana.per100g.potassium == 358)
        #expect(banana.per100g.folate == 20)
    }

    @Test func fixtureUsesFallbackNumbersAndConversions() throws {
        let lentils = try #require(try parseFixture().last)

        #expect(lentils.per100g.energy == 352, "Atwater general (957) is used when 208 is missing")
        expectApproximately(lentils.per100g.vitaminD, 1, tolerance: 1e-9)
        #expect(lentils.per100g.folate == 181, "Folate DFE (435) is used when 417 is missing")
        expectApproximately(lentils.per100g.sodium, 6)
        #expect(lentils.per100g.vitaminA == nil, "Vitamin A in IU can't be converted to RAE")
        #expect(lentils.per100g.iron == nil, "A nutrient without a value stays unknown")
    }

    private func parseFixture() throws -> [FoodItem] {
        let data = try FixtureLoader.data(named: "usda_search")
        let response = try JSONDecoder().decode(USDASearchResponse.self, from: data)
        return USDAMapper.foodItems(from: response)
    }
}
