import Foundation
import Testing
@testable import CalTracker

struct FoodSearchViewModelTests {
    private let banana = FoodItem.fixture(id: "usda-1", name: "Banana")
    private let bun = FoodItem.fixture(id: "usda-2", name: "Bun")

    @Test func movesFromLoadingToLoaded() async throws {
        let usda = StubFoodSearchProvider.controlled()
        let viewModel = makeViewModel(usda: usda, openFoodFacts: StubFoodSearchProvider(result: .success([])))

        async let search: Void = viewModel.search("banana")
        await usda.waitForRequest("banana")
        #expect(viewModel.state.results.isLoading)
        #expect(viewModel.state.query == "banana")

        usda.resolve("banana", with: .success([banana]))
        await search

        let results = try #require(viewModel.state.results.loadedValue)
        #expect(try results.usda.get() == [banana])
    }

    @Test func movesFromLoadingToFailedWithAFriendlyMessageWhenEverySourceFails() async throws {
        let offline = URLError(.notConnectedToInternet)
        let viewModel = makeViewModel(
            usda: StubFoodSearchProvider(result: .failure(offline)),
            openFoodFacts: StubFoodSearchProvider(result: .failure(offline))
        )

        await viewModel.search("banana")

        let message = try #require(viewModel.state.results.failureMessage)
        #expect(message.key == LocalizedStringResource.errorOffline.key)
    }

    @Test func staysLoadedWhenOnlyOneSourceFails() async throws {
        let viewModel = makeViewModel(
            usda: StubFoodSearchProvider(result: .success([banana])),
            openFoodFacts: StubFoodSearchProvider(result: .failure(APIError.rateLimited))
        )

        await viewModel.search("banana")

        let results = try #require(viewModel.state.results.loadedValue)
        #expect(try results.usda.get() == [banana])
        #expect(throws: APIError.rateLimited) { try results.openFoodFacts.get() }
    }

    @Test func staleResponseDoesNotOverwriteANewerQuery() async throws {
        let usda = StubFoodSearchProvider.controlled()
        let viewModel = makeViewModel(usda: usda, openFoodFacts: StubFoodSearchProvider(result: .success([])))

        async let olderSearch: Void = viewModel.search("bun")
        await usda.waitForRequest("bun")
        async let newerSearch: Void = viewModel.search("banana")
        await usda.waitForRequest("banana")

        usda.resolve("banana", with: .success([banana]))
        await newerSearch
        usda.resolve("bun", with: .success([bun]))
        await olderSearch

        let results = try #require(viewModel.state.results.loadedValue)
        #expect(viewModel.state.query == "banana")
        #expect(try results.usda.get() == [banana], "The older 'bun' response arrived last but must be ignored")
    }

    @Test(arguments: ["", "b", "ba", "  ba  "])
    func queriesShorterThanThreeCharactersStayIdle(query: String) async {
        let usda = StubFoodSearchProvider(result: .success([banana]))
        let viewModel = makeViewModel(usda: usda, openFoodFacts: StubFoodSearchProvider(result: .success([])))

        await viewModel.search(query)

        #expect(viewModel.state.results.isIdle)
        #expect(usda.receivedQueries.isEmpty)
    }

    @Test func trimsWhitespaceBeforeSearching() async {
        let usda = StubFoodSearchProvider(result: .success([banana]))
        let viewModel = makeViewModel(usda: usda, openFoodFacts: StubFoodSearchProvider(result: .success([])))

        await viewModel.search("  banana \n")

        #expect(usda.receivedQueries == ["banana"])
    }

    @Test func waitsOneAndAHalfSecondsByDefault() {
        #expect(FoodSearchViewModel.defaultDebounce == .milliseconds(1500))
    }

    @Test func typingDuringTheDebounceNeverReachesTheAPI() async {
        let usda = StubFoodSearchProvider(result: .success([banana]))
        let openFoodFacts = StubFoodSearchProvider(result: .success([]))
        let viewModel = FoodSearchViewModel(
            foodSearch: CombinedFoodSearch(usda: usda, openFoodFacts: openFoodFacts),
            debounce: .seconds(60)
        )

        // `.task(id:)` cancels the pending search when the query changes.
        let search = Task { await viewModel.search("banana") }
        search.cancel()
        await search.value

        #expect(usda.receivedQueries.isEmpty)
        #expect(openFoodFacts.receivedQueries.isEmpty)
        #expect(viewModel.state.results.isLoading == false)
    }

    private func makeViewModel(usda: StubFoodSearchProvider, openFoodFacts: StubFoodSearchProvider) -> FoodSearchViewModel {
        FoodSearchViewModel(
            foodSearch: CombinedFoodSearch(usda: usda, openFoodFacts: openFoodFacts),
            debounce: .zero
        )
    }
}
