import Testing
@testable import CalTracker

struct NutrientProfileTests {
    private let per100g = NutrientProfile(energy: 89, protein: 1.09, carbohydrates: 22.84, fat: 0.33, sodium: 1, folate: 20)

    @Test func scalingTo150GramsMultipliesEveryKnownValueByOnePointFive() {
        let scaled = per100g.scaled(byGrams: 150)

        for nutrient in Nutrient.allCases {
            if let base = per100g[nutrient] {
                expectApproximately(scaled[nutrient], base * 1.5)
            } else {
                #expect(scaled[nutrient] == nil, "\(nutrient) should stay unknown")
            }
        }
    }

    @Test func scalingToZeroGramsGivesZeroForKnownValues() {
        let scaled = per100g.scaled(byGrams: 0)

        #expect(scaled.energy == 0)
        #expect(scaled.folate == 0)
        #expect(scaled.vitaminC == nil, "Unknown values stay unknown, even at 0 g")
    }

    @Test(arguments: [-50.0, -0.1, -Double.infinity, Double.nan])
    func invalidGramAmountsAreTreatedAsZero(grams: Double) {
        let scaled = per100g.scaled(byGrams: grams)

        #expect(scaled.energy == 0)
        #expect(scaled.protein == 0)
        #expect(scaled.vitaminC == nil)
    }

    @Test func addingKeepsKnownValuesAndLeavesDoublyUnknownValuesUnknown() {
        let first = NutrientProfile(energy: 100, protein: 5)
        let second = NutrientProfile(energy: 50, fat: 2)

        let sum = first + second

        #expect(sum.energy == 150)
        #expect(sum.protein == 5)
        #expect(sum.fat == 2)
        #expect(sum.iron == nil)
    }

    @Test(arguments: Nutrient.allCases)
    func subscriptWritesOnlyTheMatchingProperty(nutrient: Nutrient) {
        var profile = NutrientProfile()

        profile[nutrient] = 1

        for other in Nutrient.allCases {
            #expect(profile[other] == (other == nutrient ? 1 : nil), "Setting \(nutrient) changed \(other)")
        }
    }
}
