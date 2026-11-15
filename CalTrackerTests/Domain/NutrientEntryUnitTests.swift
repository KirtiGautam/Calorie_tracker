import Testing
@testable import CalTracker

struct NutrientEntryUnitTests {
    @Test(arguments: [
        (Nutrient.energy, NutrientEntryUnit.kilocalories, 250.0, 250.0),
        (.energy, .kilojoules, 418.4, 100),
        (.protein, .grams, 12.5, 12.5),
        (.sodium, .grams, 0.4, 400),
        (.sodium, .micrograms, 2_500, 2.5),
        (.vitaminB12, .milligrams, 0.002, 2),
        (.vitaminD, .internationalUnits, 400, 10),
        (.vitaminD, .micrograms, 12.5, 12.5),
    ])
    func convertsIntoTheStoredUnit(nutrient: Nutrient, unit: NutrientEntryUnit, amount: Double, expected: Double) {
        expectApproximately(unit.amount(amount, of: nutrient), expected)
    }

    @Test(arguments: [
        (Nutrient.protein, NutrientEntryUnit.kilojoules),
        (.energy, .grams),
        (.vitaminA, .internationalUnits),
        (.calcium, .kilocalories),
    ])
    func refusesUnitsThatCantMeasureTheNutrient(nutrient: Nutrient, unit: NutrientEntryUnit) {
        #expect(unit.amount(1, of: nutrient) == nil)
    }

    @Test func everyNutrientStartsWithItsStoredUnitAndAcceptsAllItsUnits() {
        for nutrient in Nutrient.allCases {
            #expect(nutrient.entryUnits.first == NutrientEntryUnit(nutrient.unit), "\(nutrient)")
            for unit in nutrient.entryUnits {
                #expect(unit.amount(1, of: nutrient) != nil, "\(nutrient) in \(unit)")
            }
        }
    }

    @Test func onlyVitaminDOffersIU() {
        let offering = Nutrient.allCases.filter { $0.entryUnits.contains(.internationalUnits) }
        #expect(offering == [.vitaminD])
    }
}
