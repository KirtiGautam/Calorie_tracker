import Testing
@testable import CalTracker

struct TargetCalculatorTests {
    private let body = BodyProfile(sex: .male, age: 30, heightCentimetres: 175, weightKilograms: 70, activity: .moderate)

    @Test func maintenanceForTheWorkedExample() {
        // Resting 1,648.75 kcal × 1.55 = 2,555.6 → 2,560 kcal; protein 70 × 1.6; fat 25 % ÷ 9; carbs fill the rest.
        let targets = TargetCalculator.targets(for: body, goal: .maintain)

        #expect(targets == DailyTargets(energy: 2_560, protein: 112, carbohydrates: 368, fat: 71))
    }

    @Test(arguments: zip(
        [BiologicalSex.male, .female, .unspecified],
        [2_560.0, 2_300, 2_430]
    ))
    func sexChangesTheRestingOffset(sex: BiologicalSex, energy: Double) {
        var body = body
        body.sex = sex

        #expect(TargetCalculator.targets(for: body, goal: .maintain).energy == energy)
    }

    @Test(arguments: zip(ActivityLevel.allCases, [1_980.0, 2_270, 2_560, 2_840, 3_130]))
    func activityScalesEnergy(activity: ActivityLevel, energy: Double) {
        var body = body
        body.activity = activity

        #expect(TargetCalculator.targets(for: body, goal: .maintain).energy == energy)
    }

    @Test func cutEatsLessAndKeepsMoreProtein() {
        let targets = TargetCalculator.targets(for: body, goal: .cut)

        #expect(targets.energy == 2_040)
        #expect(targets.protein == 140)
    }

    @Test func bulkEatsMore() {
        let targets = TargetCalculator.targets(for: body, goal: .bulk)

        #expect(targets.energy == 2_810)
        #expect(targets.protein == 126)
    }

    @Test func cutNeverSuggestsLessThanTheMinimum() {
        let small = BodyProfile(sex: .female, age: 60, heightCentimetres: 150, weightKilograms: 40, activity: .sedentary)

        #expect(TargetCalculator.targets(for: small, goal: .cut).energy == TargetCalculator.minimumCutEnergy)
    }

    @Test func carbohydratesNeverGoNegative() {
        // Heavy and short, so protein alone outweighs the energy budget.
        let heavy = BodyProfile(sex: .female, age: 100, heightCentimetres: 100, weightKilograms: 300, activity: .sedentary)

        let carbohydrates = TargetCalculator.targets(for: heavy, goal: .cut).carbohydrates

        #expect(carbohydrates == 0)
    }
}
