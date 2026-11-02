import Foundation
import Testing
@testable import CalTracker

struct FoodSearchViewModelTests {
    private let banana = FoodItem.fixture(id: "usda-1", name: "Banana")
    private let bun = FoodItem.fixture(id: "usda-2", name: "Bun")
    private let biscuits = (1...4).map { FoodItem.fixture(id: "off-\($0)", name: "Biscuit \($0)", source: .openFoodFacts) }
    private let parle = BrandOption(tag: "parle", name: "Parle")
    private let isolated = IsolatedDefaults()

    @Test func movesFromLoadingToLoaded() async throws {
        let usda = StubFoodSearchProvider.controlled()
        let viewModel = makeViewModel(usda: usda, openFoodFacts: StubFoodSearchProvider(foods: []))

        async let search: Void = viewModel.search("banana")
        await usda.waitForRequest("banana")
        #expect(viewModel.state.results.isLoading)
        #expect(viewModel.state.query == "banana")

        usda.resolve("banana", foods: [banana])
        await search

        let results = try #require(viewModel.state.results.loadedValue)
        #expect(results.foods == [banana])
    }

    @Test func movesFromLoadingToFailedWithAFriendlyMessageWhenEverySourceFails() async throws {
        let offline = URLError(.notConnectedToInternet)
        let viewModel = makeViewModel(
            usda: StubFoodSearchProvider(error: offline),
            openFoodFacts: StubFoodSearchProvider(error: offline)
        )

        await viewModel.search("banana")

        let message = try #require(viewModel.state.results.failureMessage)
        #expect(message.key == LocalizedStringResource.errorOffline.key)
    }

    @Test func staysLoadedWhenOnlyOneSourceFails() async throws {
        let viewModel = makeViewModel(
            usda: StubFoodSearchProvider(foods: [banana]),
            openFoodFacts: StubFoodSearchProvider(error: APIError.rateLimited)
        )

        await viewModel.search("banana")

        let results = try #require(viewModel.state.results.loadedValue)
        #expect(results.foods == [banana])
        #expect(results.failures.map(\.source) == [.openFoodFacts])
        #expect(results.failures.first?.error as? APIError == .rateLimited)
    }

    @Test func staleResponseDoesNotOverwriteANewerQuery() async throws {
        let usda = StubFoodSearchProvider.controlled()
        let viewModel = makeViewModel(usda: usda, openFoodFacts: StubFoodSearchProvider(foods: []))

        async let olderSearch: Void = viewModel.search("bun")
        await usda.waitForRequest("bun")
        async let newerSearch: Void = viewModel.search("banana")
        await usda.waitForRequest("banana")

        usda.resolve("banana", foods: [banana])
        await newerSearch
        usda.resolve("bun", foods: [bun])
        await olderSearch

        let results = try #require(viewModel.state.results.loadedValue)
        #expect(viewModel.state.query == "banana")
        #expect(results.foods == [banana], "The older 'bun' response arrived last but must be ignored")
    }

    @Test(arguments: ["", "b", "ba", "  ba  "])
    func queriesShorterThanThreeCharactersStayIdle(query: String) async {
        let usda = StubFoodSearchProvider(foods: [banana])
        let viewModel = makeViewModel(usda: usda, openFoodFacts: StubFoodSearchProvider(foods: []))

        await viewModel.search(query)

        #expect(viewModel.state.results.isIdle)
        #expect(usda.receivedQueries.isEmpty)
    }

    @Test func trimsWhitespaceBeforeSearching() async {
        let usda = StubFoodSearchProvider(foods: [banana])
        let viewModel = makeViewModel(usda: usda, openFoodFacts: StubFoodSearchProvider(foods: []))

        await viewModel.search("  banana \n")

        #expect(usda.receivedQueries == ["banana"])
    }

    @Test func waitsOneAndAHalfSecondsByDefault() {
        #expect(FoodSearchViewModel.defaultDebounce == .milliseconds(1500))
    }

    @Test func typingDuringTheDebounceNeverReachesTheAPI() async {
        let usda = StubFoodSearchProvider(foods: [banana])
        let openFoodFacts = StubFoodSearchProvider(foods: [])
        let viewModel = makeViewModel(usda: usda, openFoodFacts: openFoodFacts, debounce: .seconds(60))

        // `.task(id:)` cancels the pending search when the query changes.
        let search = Task { await viewModel.search("banana") }
        search.cancel()
        await search.value

        #expect(usda.receivedQueries.isEmpty)
        #expect(openFoodFacts.receivedQueries.isEmpty)
        #expect(viewModel.state.results.isLoading == false)
    }

    // MARK: - Paging

    @Test func loadMoreAddsTheNextPageAfterTheFirst() async throws {
        let openFoodFacts = StubFoodSearchProvider.controlled()
        let viewModel = makeViewModel(usda: StubFoodSearchProvider(foods: [banana]), openFoodFacts: openFoodFacts)
        try await loadFirstPage(of: "biscuit", into: viewModel, from: openFoodFacts)

        async let loadMore: Void = viewModel.loadMore()
        await openFoodFacts.waitForRequest("biscuit", page: 2)
        #expect(isLoadingMore(viewModel))
        openFoodFacts.resolve("biscuit", page: 2, foods: Array(biscuits[2...]), hasMore: false)
        await loadMore

        let results = try #require(viewModel.state.results.loadedValue)
        #expect(results.foods.map(\.id) == ["usda-1", "off-1", "off-2", "off-3", "off-4"])
        #expect(results.canLoadMore == false)
        #expect(isIdle(viewModel))
    }

    @Test func loadMoreDoesNothingOnceEverySourceHasRunOut() async {
        let usda = StubFoodSearchProvider(foods: [banana])
        let viewModel = makeViewModel(usda: usda, openFoodFacts: StubFoodSearchProvider(foods: []))
        await viewModel.search("banana")

        await viewModel.loadMore()

        #expect(usda.requests.count == 1)
    }

    @Test func aLatePageForAnOlderQueryIsDropped() async throws {
        let openFoodFacts = StubFoodSearchProvider.controlled()
        let viewModel = makeViewModel(usda: StubFoodSearchProvider(foods: []), openFoodFacts: openFoodFacts)
        try await loadFirstPage(of: "biscuit", into: viewModel, from: openFoodFacts)

        async let loadMore: Void = viewModel.loadMore()
        await openFoodFacts.waitForRequest("biscuit", page: 2)
        async let newerSearch: Void = viewModel.search("cookie")
        await openFoodFacts.waitForRequest("cookie")
        openFoodFacts.resolve("cookie", foods: [biscuits[3]])
        await newerSearch
        openFoodFacts.resolve("biscuit", page: 2, foods: [biscuits[2]], hasMore: true)
        await loadMore

        let results = try #require(viewModel.state.results.loadedValue)
        #expect(viewModel.state.query == "cookie")
        #expect(results.foods.map(\.id) == ["off-4"])
        #expect(isIdle(viewModel))
    }

    @Test func aPagingFailureShowsAMessageUntilRetried() async throws {
        let openFoodFacts = StubFoodSearchProvider.controlled()
        let viewModel = makeViewModel(usda: StubFoodSearchProvider(foods: []), openFoodFacts: openFoodFacts)
        try await loadFirstPage(of: "biscuit", into: viewModel, from: openFoodFacts)

        async let failedLoad: Void = viewModel.loadMore()
        await openFoodFacts.waitForRequest("biscuit", page: 2)
        openFoodFacts.resolve("biscuit", page: 2, with: .failure(APIError.rateLimited))
        await failedLoad

        guard case .failed(let message) = viewModel.state.paging else {
            Issue.record("Expected a paging failure, got \(viewModel.state.paging)")
            return
        }
        #expect(message.key == LocalizedStringResource.errorRateLimited.key)
        // Failed pages are never retried on their own, to protect the rate limit.
        await viewModel.loadMore()
        #expect(openFoodFacts.requests.count == 2)

        viewModel.retryLoadMore()
        #expect(isIdle(viewModel))
        async let retry: Void = viewModel.loadMore()
        await openFoodFacts.waitForRequest("biscuit", page: 2, occurrence: 2)
        openFoodFacts.resolve("biscuit", page: 2, foods: [biscuits[2]])
        await retry

        let results = try #require(viewModel.state.results.loadedValue)
        #expect(results.foods.map(\.id) == ["off-1", "off-2", "off-3"])
        #expect(openFoodFacts.requests.map(\.page) == [1, 2, 2])
    }

    @Test func cancellationIsNotShownAsAFailure() async throws {
        let openFoodFacts = StubFoodSearchProvider.controlled()
        let viewModel = makeViewModel(usda: StubFoodSearchProvider(foods: []), openFoodFacts: openFoodFacts)
        try await loadFirstPage(of: "biscuit", into: viewModel, from: openFoodFacts)

        // The row's task is cancelled when it scrolls away, and the request fails with a cancellation error.
        let load = Task { await viewModel.loadMore() }
        await openFoodFacts.waitForRequest("biscuit", page: 2)
        load.cancel()
        openFoodFacts.resolve("biscuit", page: 2, with: .failure(URLError(.cancelled)))
        await load.value

        #expect(isIdle(viewModel))
        let results = try #require(viewModel.state.results.loadedValue)
        #expect(results.cursor.openFoodFacts == 2, "The page that didn't load is asked for again next time")
    }

    // MARK: - Filters

    @Test func startsFromTheSavedCountryFilter() {
        SearchPreferencesStore(defaults: isolated.defaults).save(regionFilterEnabled: true, regionCode: "IN")

        let viewModel = makeViewModel(usda: StubFoodSearchProvider(foods: []), openFoodFacts: StubFoodSearchProvider(foods: []))

        #expect(viewModel.filters == FoodSearchFilters(regionEnabled: true, regionCode: "IN"))
    }

    @Test func aFilterChangeSearchesAgainWithoutTheDebounce() async {
        let openFoodFacts = StubFoodSearchProvider(foods: [])
        let viewModel = makeViewModel(
            usda: StubFoodSearchProvider(foods: []),
            openFoodFacts: openFoodFacts,
            debounce: .seconds(60)
        )

        viewModel.applyFilters(FoodSearchFilters(regionEnabled: true, regionCode: "IN"))
        #expect(viewModel.filtersRevision == 1)
        // A 60 second debounce would time the test out, so finishing at all shows it was skipped.
        await viewModel.search("biscuit")

        #expect(openFoodFacts.requests.map(\.filters.activeRegionCode) == ["IN"])
        #expect(viewModel.state.results.loadedValue != nil)
    }

    @Test func onlyTheFirstSearchAfterAFilterChangeSkipsTheDebounce() async {
        let openFoodFacts = StubFoodSearchProvider(foods: [])
        let viewModel = makeViewModel(
            usda: StubFoodSearchProvider(foods: []),
            openFoodFacts: openFoodFacts,
            debounce: .seconds(60)
        )
        viewModel.applyFilters(FoodSearchFilters(brand: .name("Parle")))
        await viewModel.search("biscuit")

        let typing = Task { await viewModel.search("biscuits") }
        typing.cancel()
        await typing.value

        #expect(openFoodFacts.receivedQueries == ["biscuit"])
    }

    @Test func aChangeThatDoesNotAffectResultsDoesNotSearchAgain() {
        let viewModel = makeViewModel(usda: StubFoodSearchProvider(foods: []), openFoodFacts: StubFoodSearchProvider(foods: []))

        viewModel.applyFilters(FoodSearchFilters(regionEnabled: false, regionCode: "GB"))

        #expect(viewModel.filtersRevision == 0)
        #expect(viewModel.filters.regionCode == "GB")
    }

    @Test func turningTheCountryFilterOnWithoutACountryLeavesItOff() {
        let viewModel = makeViewModel(usda: StubFoodSearchProvider(foods: []), openFoodFacts: StubFoodSearchProvider(foods: []))

        viewModel.applyFilters(FoodSearchFilters(regionEnabled: true, regionCode: nil))

        #expect(viewModel.filters.regionEnabled == false)
        #expect(viewModel.filtersRevision == 0)
        #expect(SearchPreferencesStore(defaults: isolated.defaults).regionFilterEnabled == false)
    }

    @Test func savesTheCountrySetting() {
        let viewModel = makeViewModel(usda: StubFoodSearchProvider(foods: []), openFoodFacts: StubFoodSearchProvider(foods: []))

        viewModel.applyFilters(FoodSearchFilters(regionEnabled: true, regionCode: "IN", brand: .tag("parle", name: "Parle")))

        let saved = SearchPreferencesStore(defaults: isolated.defaults)
        #expect(saved.regionFilterEnabled)
        #expect(saved.regionCode == "IN")
        #expect(saved.filters.brand == nil, "The brand belongs to one query and isn't saved")
    }

    @Test func clearFiltersTurnsEverythingOffButKeepsTheCountry() {
        let viewModel = makeViewModel(usda: StubFoodSearchProvider(foods: []), openFoodFacts: StubFoodSearchProvider(foods: []))
        viewModel.applyFilters(FoodSearchFilters(regionEnabled: true, regionCode: "IN", brand: .name("Parle")))

        viewModel.clearFilters()

        #expect(viewModel.filters == FoodSearchFilters(regionEnabled: false, regionCode: "IN"))
        #expect(viewModel.filters.isActive == false)
        #expect(viewModel.filtersRevision == 2)
    }

    @Test func changingTheQueryClearsTheBrand() async {
        let openFoodFacts = StubFoodSearchProvider(result: .success(FoodSearchPage(foods: biscuits, brands: [parle])))
        let viewModel = makeViewModel(usda: StubFoodSearchProvider(foods: []), openFoodFacts: openFoodFacts)
        await viewModel.search("biscuit")
        viewModel.applyFilters(FoodSearchFilters(regionEnabled: true, regionCode: "IN", brand: parle.filter))
        await viewModel.search("biscuit")

        await viewModel.search("cookie")

        #expect(viewModel.filters.brand == nil)
        #expect(viewModel.filters.activeRegionCode == "IN", "Only the brand belongs to the query")
        #expect(openFoodFacts.requests.map(\.filters.brand) == [nil, parle.filter, nil])
    }

    @Test func aBrandChosenBeforeAnySearchIsKeptForTheFirstOne() async {
        let openFoodFacts = StubFoodSearchProvider(foods: [])
        let viewModel = makeViewModel(usda: StubFoodSearchProvider(foods: []), openFoodFacts: openFoodFacts)

        viewModel.applyFilters(FoodSearchFilters(brand: .name("Karachi Bakery")))
        await viewModel.search("biscuit")

        #expect(viewModel.filters.brand == .name("Karachi Bakery"))
        #expect(openFoodFacts.requests.map(\.filters.brand) == [.name("Karachi Bakery")])
    }

    @Test func theBrandListIsKeptWhileABrandIsSelected() async {
        let britannia = BrandOption(tag: "britannia", name: "Britannia")
        let openFoodFacts = StubFoodSearchProvider.controlled()
        let viewModel = makeViewModel(usda: StubFoodSearchProvider(foods: []), openFoodFacts: openFoodFacts)

        async let first: Void = viewModel.search("biscuit")
        await openFoodFacts.waitForRequest("biscuit")
        openFoodFacts.resolve("biscuit", foods: biscuits, brands: [parle, britannia])
        await first
        #expect(viewModel.brandOptions == [parle, britannia])

        viewModel.applyFilters(FoodSearchFilters(brand: parle.filter))
        async let filtered: Void = viewModel.search("biscuit")
        await openFoodFacts.waitForRequest("biscuit", occurrence: 2)
        openFoodFacts.resolve("biscuit", foods: [biscuits[0]], brands: [parle])
        await filtered

        #expect(viewModel.brandOptions == [parle, britannia])
    }

    // MARK: - Helpers

    /// Searches `query` and answers page 1 from `openFoodFacts` with two biscuits and more to come.
    private func loadFirstPage(
        of query: String,
        into viewModel: FoodSearchViewModel,
        from openFoodFacts: StubFoodSearchProvider
    ) async throws {
        async let search: Void = viewModel.search(query)
        await openFoodFacts.waitForRequest(query)
        openFoodFacts.resolve(query, foods: Array(biscuits.prefix(2)), hasMore: true)
        await search
        let results = try #require(viewModel.state.results.loadedValue)
        try #require(results.canLoadMore)
    }

    private func isIdle(_ viewModel: FoodSearchViewModel) -> Bool {
        if case .idle = viewModel.state.paging { true } else { false }
    }

    private func isLoadingMore(_ viewModel: FoodSearchViewModel) -> Bool {
        if case .loading = viewModel.state.paging { true } else { false }
    }

    private func makeViewModel(
        usda: StubFoodSearchProvider,
        openFoodFacts: StubFoodSearchProvider,
        debounce: Duration = .zero
    ) -> FoodSearchViewModel {
        FoodSearchViewModel(
            foodSearch: CombinedFoodSearch(usda: usda, openFoodFacts: openFoodFacts),
            preferences: SearchPreferencesStore(defaults: isolated.defaults),
            debounce: debounce
        )
    }
}
