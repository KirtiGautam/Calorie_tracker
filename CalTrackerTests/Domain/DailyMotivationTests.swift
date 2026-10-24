import Foundation
import Testing
@testable import CalTracker

struct DailyMotivationTests {
    @Test func noTargetsMeansNoMessage() {
        let totals = DailyTotals(entries: [NutrientProfile(energy: 500)])

        #expect(DailyMotivation(targets: DailyTargets(), totals: totals, hasEntries: true) == nil)
    }

    @Test func nothingLoggedIsAFreshStart() {
        let motivation = DailyMotivation(
            targets: DailyTargets(energy: 2_000),
            totals: DailyTotals(entries: []),
            hasEntries: false
        )

        #expect(motivation == .freshStart)
    }

    @Test func carbohydrateSurplusOutranksEnergyStillToGo() {
        let totals = DailyTotals(entries: [NutrientProfile(energy: 500, carbohydrates: 150)])

        let motivation = DailyMotivation(
            targets: DailyTargets(energy: 2_000, carbohydrates: 100),
            totals: totals,
            hasEntries: true
        )

        #expect(motivation == .carbohydratesOver)
    }

    @Test func everyTargetReachedIsCelebrated() {
        // A protein surplus is fine, so it still counts as met.
        let totals = DailyTotals(entries: [NutrientProfile(energy: 2_000, protein: 150)])

        let motivation = DailyMotivation(
            targets: DailyTargets(energy: 2_000, protein: 100),
            totals: totals,
            hasEntries: true
        )

        #expect(motivation == .allTargetsMet)
    }

    @Test func energyStillShortShowsWhatsLeft() throws {
        let totals = DailyTotals(entries: [NutrientProfile(energy: 1_380, protein: 100)])

        let motivation = try #require(DailyMotivation(
            targets: DailyTargets(energy: 2_000, protein: 100),
            totals: totals,
            hasEntries: true
        ))

        #expect(motivation == .energyRemaining(kilocalories: 620))
        #expect(String(localized: motivation.message).contains(NutrientUnit.kilocalories.formatted(620)))
    }

    @Test func otherShortfallsCountTargetsMet() {
        let totals = DailyTotals(entries: [NutrientProfile(energy: 2_000, protein: 50, fat: 10)])

        let motivation = DailyMotivation(
            targets: DailyTargets(energy: 2_000, protein: 100, fat: 60),
            totals: totals,
            hasEntries: true
        )

        #expect(motivation == .targetsProgress(met: 1, total: 3))
    }

    @Test(arguments: zip(
        [DailyMotivation.freshStart, .carbohydratesOver, .allTargetsMet, .energyRemaining(kilocalories: 100), .targetsProgress(met: 1, total: 2)],
        [TargetTone.good, .alert, .good, .caution, .caution]
    ))
    func toneMatchesTheProgressBars(motivation: DailyMotivation, tone: TargetTone) {
        #expect(motivation.tone == tone)
    }
}
