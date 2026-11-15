import Testing
@testable import CalTracker

struct CustomFoodViewModelTests {
    @Test func startsFromTheSearchTextFor100Grams() {
        let viewModel = CustomFoodViewModel(store: FakeCustomFoodStore(), name: "rajma")

        #expect(viewModel.draft.name == "rajma")
        #expect(viewModel.draft.referenceGrams == CustomFoodDraft.defaultReferenceGrams)
        #expect(viewModel.canSave == false)
        #expect(viewModel.issue == nil)
    }

    @Test func previewsTheValuesPer100GramsAndListsEnteredMicros() throws {
        let viewModel = CustomFoodViewModel(store: FakeCustomFoodStore(), name: "Dal")
        viewModel.draft.referenceGrams = 200
        viewModel.draft[.energy] = 240
        viewModel.draft[.iron] = 4

        let preview = try #require(viewModel.preview)
        expectApproximately(preview.energy, 120)
        expectApproximately(preview.iron, 2)
        #expect(viewModel.previewNutrients == Nutrient.macros + [.iron])
        #expect(viewModel.canSave)
    }

    @Test func explainsValuesThatCantBeStandardized() {
        let viewModel = CustomFoodViewModel(store: FakeCustomFoodStore(), name: "Dal")
        viewModel.draft[.protein] = 10

        #expect(viewModel.issue?.key == userMessage(for: CustomFoodError.missingEnergy).key)
        #expect(viewModel.canSave == false)
    }

    @Test func needsANameToSave() {
        let viewModel = CustomFoodViewModel(store: FakeCustomFoodStore())
        viewModel.draft[.energy] = 100

        #expect(viewModel.issue == nil)
        #expect(viewModel.canSave == false)
    }

    @Test func saveStoresTheStandardizedFood() throws {
        let store = FakeCustomFoodStore()
        let viewModel = CustomFoodViewModel(store: store, name: "Dal")
        viewModel.draft.referenceGrams = 350
        viewModel.draft[.energy] = 420

        let record = try viewModel.save()

        #expect(store.records == [record])
        #expect(record.food.source == .custom)
        #expect(record.servingGrams == 350)
        expectApproximately(record.food.per100g.energy, 120)
    }

    @Test func aFailedSaveThrowsTheStoresError() {
        let store = FakeCustomFoodStore()
        store.errorToThrow = LogFoodError.invalidAmount
        let viewModel = CustomFoodViewModel(store: store, name: "Dal")
        viewModel.draft[.energy] = 100

        #expect(throws: LogFoodError.invalidAmount) { try viewModel.save() }
    }
}
