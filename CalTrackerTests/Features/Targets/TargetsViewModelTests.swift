import Testing
@testable import CalTracker

struct TargetsViewModelTests {
    private let isolated = IsolatedDefaults()
    private let body = BodyProfile(sex: .male, age: 30, heightCentimetres: 175, weightKilograms: 70, activity: .moderate)

    private var store: TargetsStore {
        TargetsStore(defaults: isolated.defaults)
    }

    @Test func startsFromDefaultsWhenNothingIsSaved() {
        let viewModel = TargetsViewModel(store: store)

        #expect(viewModel.goal == .maintain)
        #expect(viewModel.sex == .unspecified)
        #expect(viewModel.activity == .moderate)
        #expect(viewModel.age == nil)
        #expect(viewModel.targets.isEmpty)
        #expect(viewModel.canCalculate == false)
    }

    @Test func prefillsFromTheStore() throws {
        let targets = DailyTargets(energy: 2_000, protein: 150)
        try store.save(targets: targets, bodyProfile: body, goal: .cut)

        let viewModel = TargetsViewModel(store: store)

        #expect(viewModel.goal == .cut)
        #expect(viewModel.bodyProfile == body)
        #expect(viewModel.targets == targets)
    }

    @Test(arguments: zip(
        [14, 15, 100, 101],
        [false, true, true, false]
    ))
    func ageMustBeInRange(age: Int, canCalculate: Bool) {
        let viewModel = makeFilledViewModel()

        viewModel.age = age

        #expect(viewModel.canCalculate == canCalculate)
    }

    @Test(arguments: zip(
        [99.9, 100, 250, 250.1],
        [false, true, true, false]
    ))
    func heightMustBeInRange(height: Double, canCalculate: Bool) {
        let viewModel = makeFilledViewModel()

        viewModel.heightCentimetres = height

        #expect(viewModel.canCalculate == canCalculate)
    }

    @Test(arguments: zip(
        [29.9, 30, 300, 300.1],
        [false, true, true, false]
    ))
    func weightMustBeInRange(weight: Double, canCalculate: Bool) {
        let viewModel = makeFilledViewModel()

        viewModel.weightKilograms = weight

        #expect(viewModel.canCalculate == canCalculate)
    }

    @Test func calculateUsesTheGoal() {
        let viewModel = makeFilledViewModel()
        viewModel.goal = .cut

        viewModel.calculate()

        #expect(viewModel.targets == TargetCalculator.targets(for: body, goal: .cut))
    }

    @Test func calculateDoesNothingWithoutMeasurements() {
        let viewModel = TargetsViewModel(store: store)
        viewModel.targets.protein = 150

        viewModel.calculate()

        #expect(viewModel.targets == DailyTargets(protein: 150))
    }

    @Test(arguments: [0.0, -5, .nan, .infinity])
    func invalidTargetsCantBeSaved(protein: Double) {
        let viewModel = TargetsViewModel(store: store)
        viewModel.targets.protein = protein

        #expect(viewModel.isValid == false)
        #expect(throws: LogFoodError.invalidAmount) {
            try viewModel.save()
        }
        #expect(store.targets.isEmpty)
    }

    @Test func blankTargetsAreValid() {
        #expect(TargetsViewModel(store: store).isValid)
    }

    @Test func savePersistsEverything() throws {
        let viewModel = makeFilledViewModel()
        viewModel.goal = .bulk
        viewModel.calculate()
        viewModel.targets.protein = 160

        try viewModel.save()

        let saved = store
        #expect(saved.goal == .bulk)
        #expect(saved.bodyProfile == body)
        #expect(saved.targets.protein == 160)
        #expect(saved.targets.energy == 2_810)
    }

    @Test func incompleteMeasurementsSaveAsNilButKeepTheGoal() throws {
        let viewModel = TargetsViewModel(store: store)
        viewModel.goal = .cut
        viewModel.age = 30
        viewModel.targets = DailyTargets(energy: 1_800)

        try viewModel.save()

        let saved = store
        #expect(saved.bodyProfile == nil)
        #expect(saved.goal == .cut)
        #expect(saved.targets == DailyTargets(energy: 1_800))
    }

    private func makeFilledViewModel() -> TargetsViewModel {
        let viewModel = TargetsViewModel(store: store)
        viewModel.sex = body.sex
        viewModel.age = body.age
        viewModel.heightCentimetres = body.heightCentimetres
        viewModel.weightKilograms = body.weightKilograms
        viewModel.activity = body.activity
        return viewModel
    }
}
