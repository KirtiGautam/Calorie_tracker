import Testing
@testable import CalTracker

struct TargetProgressTests {
    @Test(arguments: zip(
        [0.0, 89.9, 90, 100, 110, 110.1],
        [TargetStatus.deficit, .deficit, .onTarget, .onTarget, .onTarget, .surplus]
    ))
    func statusUsesATenPercentBand(total: Double, status: TargetStatus) {
        let progress = TargetProgress(nutrient: .protein, total: total, target: 100)

        #expect(progress.status == status)
    }

    @Test(arguments: Nutrient.macros)
    func everyDeficitIsACaution(nutrient: Nutrient) {
        #expect(TargetProgress(nutrient: nutrient, total: 10, target: 100).tone == .caution)
    }

    @Test(arguments: Nutrient.macros)
    func onTargetIsGood(nutrient: Nutrient) {
        #expect(TargetProgress(nutrient: nutrient, total: 100, target: 100).tone == .good)
    }

    @Test(arguments: zip(Nutrient.macros, [TargetTone.good, .good, .alert, .good]))
    func onlyACarbohydrateSurplusIsAnAlert(nutrient: Nutrient, tone: TargetTone) {
        #expect(TargetProgress(nutrient: nutrient, total: 200, target: 100).tone == tone)
    }

    @Test func differenceIsAlwaysPositive() {
        #expect(TargetProgress(nutrient: .fat, total: 40, target: 65).difference == 25)
        #expect(TargetProgress(nutrient: .fat, total: 80, target: 65).difference == 15)
    }

    @Test func unknownTotalCountsAsZero() throws {
        let totals = DailyTotals(entries: [NutrientProfile(energy: 100)])
        let targets = DailyTargets(protein: 150)

        let progress = try #require(targets.progress(for: .protein, in: totals))

        #expect(progress.total == 0)
        #expect(progress.status == .deficit)
    }

    @Test func noTargetMeansNoProgress() {
        let totals = DailyTotals(entries: [NutrientProfile(energy: 100)])

        #expect(DailyTargets(energy: 2_000).progress(for: .fat, in: totals) == nil)
        #expect(DailyTargets(energy: 2_000).progress(for: .iron, in: totals) == nil)
    }

    @Test func emptyTargetsAreEmpty() {
        #expect(DailyTargets().isEmpty)
        #expect(DailyTargets(fat: 60).isEmpty == false)
    }
}
