import Testing
@testable import CalTracker

struct CustomFoodsViewModelTests {
    private let dal = CustomFoodRecord.fixture(id: "cus-1", name: "Grandma's dal")
    private let kheer = CustomFoodRecord.fixture(id: "cus-2", name: "Kheer")

    @Test func aBlankQueryListsEveryFood() {
        let viewModel = CustomFoodsViewModel(store: FakeCustomFoodStore(records: [kheer, dal]))

        viewModel.load(matching: "")

        #expect(viewModel.foods == [kheer, dal])
        #expect(viewModel.hasContent)
    }

    @Test func aQueryListsOnlyMatches() {
        let viewModel = CustomFoodsViewModel(store: FakeCustomFoodStore(records: [kheer, dal]))

        viewModel.load(matching: "dal")

        #expect(viewModel.foods == [dal])
    }

    @Test func noFoodsHasNothingToShow() {
        let viewModel = CustomFoodsViewModel(store: FakeCustomFoodStore())

        viewModel.load(matching: "")

        #expect(viewModel.hasContent == false)
    }

    @Test func reloadPicksUpANewFoodForTheSameQuery() throws {
        let store = FakeCustomFoodStore(records: [dal])
        let viewModel = CustomFoodsViewModel(store: store)
        viewModel.load(matching: "k")

        try store.save(kheer)
        viewModel.reload()

        #expect(viewModel.foods == [kheer])
    }

    @Test func deleteRemovesTheFood() throws {
        let viewModel = CustomFoodsViewModel(store: FakeCustomFoodStore(records: [kheer, dal]))
        viewModel.load(matching: "")

        try viewModel.delete(kheer)

        #expect(viewModel.foods == [dal])
    }

    @Test func aFailedLoadShowsWhy() {
        let store = FakeCustomFoodStore(records: [dal])
        store.errorToThrow = APIError.invalidResponse
        let viewModel = CustomFoodsViewModel(store: store)

        viewModel.load(matching: "")

        #expect(viewModel.foods.isEmpty)
        #expect(viewModel.loadFailure?.key == userMessage(for: APIError.invalidResponse).key)
        #expect(viewModel.hasContent)
    }
}
