import Testing
@testable import CalTracker

struct DailyTotalsTests {
    @Test func sumsEveryEntry() {
        let banana = NutrientProfile(energy: 133.5, protein: 1.6, potassium: 537)
        let nutella = NutrientProfile(energy: 808.5, protein: 9.5, potassium: 600)

        let totals = DailyTotals(entries: [banana, nutella])

        expectApproximately(totals.profile.energy, 942)
        expectApproximately(totals.profile.protein, 11.1)
        expectApproximately(totals.profile.potassium, 1_137)
        #expect(totals.partialNutrients.isEmpty)
    }

    @Test func marksNutrientsSomeEntriesLackAsPartial() {
        let complete = NutrientProfile(energy: 100, iron: 2)
        let missingIron = NutrientProfile(energy: 50)

        let totals = DailyTotals(entries: [complete, missingIron])

        #expect(totals.profile.iron == 2)
        #expect(totals.isPartial(.iron))
        #expect(totals.isPartial(.energy) == false)
    }

    @Test func leavesNutrientsNoEntryReportedUnknownAndNotPartial() {
        let totals = DailyTotals(entries: [NutrientProfile(energy: 100), NutrientProfile(energy: 20)])

        #expect(totals.profile.vitaminD == nil)
        #expect(totals.isPartial(.vitaminD) == false)
    }

    @Test func noEntriesMeansZeroOfEverything() {
        let totals = DailyTotals(entries: [])

        for nutrient in Nutrient.allCases {
            #expect(totals.profile[nutrient] == 0, "\(nutrient) should be 0 on an empty day")
        }
        #expect(totals.partialNutrients.isEmpty)
    }
}
