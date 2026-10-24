import Testing
@testable import CalTracker

struct NutrientTests {
    @Test(arguments: [
        (Nutrient.energy, 0.0),
        (.energy, 900),
        (.fat, 100),
        (.sodium, 100_000),
        (.vitaminD, 100_000_000),
    ])
    func keepsAmountsThatCanBeReal(nutrient: Nutrient, amount: Double) {
        #expect(nutrient.plausibleAmountPer100g(amount) == amount)
    }

    @Test(arguments: [
        (Nutrient.energy, -0.1),
        (.energy, 900.5),
        (.energy, .nan),
        (.energy, .infinity),
        (.protein, -3),
        (.sugar, 100.1),
        (.sodium, 100_001),
        (.iron, .nan),
    ])
    func rejectsNegativeNonFiniteAndImpossiblyLargeAmounts(nutrient: Nutrient, amount: Double) {
        #expect(nutrient.plausibleAmountPer100g(amount) == nil)
    }
}
