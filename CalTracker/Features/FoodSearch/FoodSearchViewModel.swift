import Foundation
import Observation

/// Debounces queries, searches both food databases page by page and publishes the outcome as `FoodSearchState`.
@Observable
final class FoodSearchViewModel {
    /// The shortest query that triggers a search, which also keeps Open Food Facts' rate limit in reach.
    static let minimumQueryLength = 3

    /// How long to wait after the last keystroke before searching, so typing doesn't burn through API rate limits.
    static let defaultDebounce: Duration = .milliseconds(1500)

    /// What the search screen shows.
    private(set) var state = FoodSearchState()

    /// The country and brand filters applied to Open Food Facts results.
    private(set) var filters: FoodSearchFilters

    /// Goes up each time a filter change affects the results, so the view knows to search again.
    private(set) var filtersRevision = 0

    /// The most common brands from the latest search without a brand filter.
    ///
    /// They're kept while a brand is selected, so the person can switch to another one.
    private(set) var brandOptions: [BrandOption] = []

    @ObservationIgnored private let foodSearch: CombinedFoodSearch
    @ObservationIgnored private let preferences: SearchPreferencesStore
    @ObservationIgnored private let debounce: Duration

    /// Increments for every call to `search(_:)` so slower, older responses can be recognized and ignored.
    @ObservationIgnored private var latestSearchID = 0

    /// Whether the next search follows a filter change, which needs no debounce because it isn't typing.
    @ObservationIgnored private var skipsNextDebounce = false

    /// The filters the current results were searched with, so later pages match the first.
    @ObservationIgnored private var resultsFilters = FoodSearchFilters()

    /// The query the brand filter was last searched with. Searching a different query clears the brand.
    @ObservationIgnored private var brandQuery: String?

    /// Creates a view model that starts from the saved country filter and waits `debounce` after the last keystroke.
    init(foodSearch: CombinedFoodSearch, preferences: SearchPreferencesStore, debounce: Duration = defaultDebounce) {
        self.foodSearch = foodSearch
        self.preferences = preferences
        self.debounce = debounce
        filters = preferences.filters
    }

    /// Searches for `query`, after the debounce interval unless a filter just changed.
    ///
    /// Call this from `.task(id:)` so typing cancels the previous search. Cancellation
    /// and responses for older queries leave the state untouched. A new query clears the brand filter,
    /// because the brands on offer belong to a query.
    func search(_ query: String) async {
        latestSearchID += 1
        let searchID = latestSearchID
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let skipsDebounce = skipsNextDebounce
        skipsNextDebounce = false

        guard trimmed.count >= Self.minimumQueryLength else {
            state = FoodSearchState(query: trimmed, results: .idle)
            return
        }

        if skipsDebounce == false, debounce > .zero {
            do {
                try await Task.sleep(for: debounce)
            } catch {
                // Only cancellation interrupts the sleep, and a newer query has replaced this one.
                return
            }
        }
        guard searchID == latestSearchID else { return }

        clearBrandIfQueryChanged(to: trimmed)
        let filters = filters
        resultsFilters = filters
        state = FoodSearchState(query: trimmed, results: .loading)
        let batch = await foodSearch.search(trimmed, filters: filters)
        guard searchID == latestSearchID, Task.isCancelled == false else { return }

        let results = FoodSearchResults(firstBatch: batch)
        if let error = results.errorIfAllFailed {
            state.results = .failed(userMessage(for: error))
        } else {
            state.results = .loaded(results)
        }
        if filters.brand == nil {
            brandOptions = results.brands
        }
    }

    /// Loads the next page of the current results and adds it to the end.
    ///
    /// Call this from `.task(id:)` on the row at the end of the list. It does nothing while a page is loading,
    /// after a page failed, or once every source has run out. A page for an older search is dropped. If the task
    /// is cancelled, any source that already answered is kept and no error is shown.
    func loadMore() async {
        guard case .loaded(let results) = state.results, results.canLoadMore, case .idle = state.paging else { return }
        let searchID = latestSearchID

        state.paging = .loading
        let batch = await foodSearch.search(state.query, filters: resultsFilters, cursor: results.cursor)
        guard searchID == latestSearchID, case .loaded(var current) = state.results else { return }

        let failures = current.append(batch)
        state.results = .loaded(current)
        if let failure = failures.first, Task.isCancelled == false {
            state.paging = .failed(userMessage(for: failure.error))
        } else {
            state.paging = .idle
        }
    }

    /// Clears a paging failure so the end-of-list row loads the page again.
    func retryLoadMore() {
        guard case .failed = state.paging else { return }
        state.paging = .idle
    }

    /// Applies `newFilters` and saves the country setting.
    ///
    /// Turning the country filter on without choosing a country leaves it off. The view searches again only
    /// when the change affects the results.
    func applyFilters(_ newFilters: FoodSearchFilters) {
        var applied = newFilters
        if applied.regionCode == nil {
            applied.regionEnabled = false
        }
        preferences.save(regionFilterEnabled: applied.regionEnabled, regionCode: applied.regionCode)

        let changesResults = applied.activeRegionCode != filters.activeRegionCode || applied.brand != filters.brand
        filters = applied
        if changesResults {
            skipsNextDebounce = true
            filtersRevision += 1
        }
    }

    /// Turns the country filter off and removes the brand, keeping the chosen country for next time.
    func clearFilters() {
        applyFilters(FoodSearchFilters(regionEnabled: false, regionCode: filters.regionCode))
    }

    /// Removes the brand filter when it was last searched with a query other than `query`.
    ///
    /// A brand chosen before any search is kept for the first one.
    private func clearBrandIfQueryChanged(to query: String) {
        if let brandQuery, brandQuery != query {
            filters.brand = nil
        }
        brandQuery = filters.brand == nil ? nil : query
    }
}
