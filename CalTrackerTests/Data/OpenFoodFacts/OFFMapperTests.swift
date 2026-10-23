import Foundation
import Testing
@testable import CalTracker

struct OFFMapperTests {
    /// Each nutrient's OFF field and the factor from OFF's grams to the nutrient's display unit.
    nonisolated static let fieldTable: [(Nutrient, String, Double)] = [
        (.energy, "energy-kcal_100g", 1),
        (.protein, "proteins_100g", 1),
        (.carbohydrates, "carbohydrates_100g", 1),
        (.fat, "fat_100g", 1),
        (.fiber, "fiber_100g", 1),
        (.sugar, "sugars_100g", 1),
        (.saturatedFat, "saturated-fat_100g", 1),
        (.cholesterol, "cholesterol_100g", 1_000),
        (.sodium, "sodium_100g", 1_000),
        (.potassium, "potassium_100g", 1_000),
        (.calcium, "calcium_100g", 1_000),
        (.iron, "iron_100g", 1_000),
        (.magnesium, "magnesium_100g", 1_000),
        (.zinc, "zinc_100g", 1_000),
        (.vitaminC, "vitamin-c_100g", 1_000),
        (.vitaminA, "vitamin-a_100g", 1_000_000),
        (.vitaminD, "vitamin-d_100g", 1_000_000),
        (.vitaminB12, "vitamin-b12_100g", 1_000_000),
        (.folate, "folates_100g", 1_000_000),
    ]

    @Test func fieldTableCoversEveryNutrient() {
        #expect(Set(Self.fieldTable.map(\.0)) == Set(Nutrient.allCases))
    }

    @Test(arguments: fieldTable)
    func mapsEachNutrientFieldAndConvertsItsUnit(nutrient: Nutrient, field: String, factor: Double) {
        let profile = OFFMapper.profile(from: OFFSearchResponse.Nutriments(values: [field: 0.5]))

        expectApproximately(profile[nutrient], 0.5 * factor)
    }

    @Test func fixtureKeepsOnlyProductsWithANameAndEnergy() throws {
        let foods = try parseFixture()

        #expect(foods.map(\.name) == ["Nutella", "Oat Biscuits"])
    }

    @Test func fixtureMapsNutellaAndConvertsGramsToMilligrams() throws {
        let nutella = try #require(try parseFixture().first)

        #expect(nutella.id == "off-3017620422003")
        #expect(nutella.brand == "Ferrero")
        #expect(nutella.source == .openFoodFacts)
        #expect(nutella.per100g.energy == 539, "kcal is preferred over the kJ energy_100g field")
        expectApproximately(nutella.per100g.protein, 6.3)
        expectApproximately(nutella.per100g.sodium, 42.8)
        #expect(nutella.per100g.fiber == nil)
    }

    @Test func fixtureFallsBackToKilojoulesAndConvertsMicrograms() throws {
        let biscuits = try #require(try parseFixture().last)

        #expect(biscuits.id == "off-5000159484695", "Numeric barcodes are read as strings")
        #expect(biscuits.brand == nil, "An empty brands field means no brand")
        expectApproximately(biscuits.per100g.energy, 2_000 / 4.184)
        expectApproximately(biscuits.per100g.calcium, 120)
        expectApproximately(biscuits.per100g.vitaminD, 2.5)
        expectApproximately(biscuits.per100g.vitaminB12, 0.4)
    }

    private func parseFixture() throws -> [FoodItem] {
        let data = try FixtureLoader.data(named: "off_search")
        let response = try JSONDecoder().decode(OFFSearchResponse.self, from: data)
        return OFFMapper.foodItems(from: response)
    }
}
