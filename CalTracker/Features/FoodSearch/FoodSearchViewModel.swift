import Foundation
import Observation

/// Debounces queries, searches both food databases and publishes the outcome as `FoodSearchState`.
@Observable
final class FoodSearchViewModel {
    /// The shortest query that triggers a search, which also keeps Open Food Facts' rate limit in reach.
    static let minimumQueryLength = 3

    /// How long to wait after the last keystroke before searching, so typing doesn't burn through API rate limits.
    static let defaultDebounce: Duration = .milliseconds(1500)

    /// What the search screen shows.
    private(set) var state = FoodSearchState()

    @ObservationIgnored private let foodSearch: CombinedFoodSearch
    @ObservationIgnored private let debounce: Duration

    /// Increments for every call to `search(_:)` so slower, older responses can be recognized and ignored.
    @ObservationIgnored private var latestSearchID = 0

    /// Creates a view model that waits `debounce` after the last keystroke before searching.
    init(foodSearch: CombinedFoodSearch, debounce: Duration = defaultDebounce) {
        self.foodSearch = foodSearch
        self.debounce = debounce
    }

    /// Searches for `query` after the debounce interval.
    ///
    /// Call this from `.task(id:)` so typing cancels the previous search. Cancellation
    /// and responses for older queries leave the state untouched.
    func search(_ query: String) async {
        latestSearchID += 1
        let searchID = latestSearchID
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= Self.minimumQueryLength else {
            state = FoodSearchState(query: trimmed, results: .idle)
            return
        }

        if debounce > .zero {
            do {
                try await Task.sleep(for: debounce)
            } catch {
                // Only cancellation interrupts the sleep, and a newer query has replaced this one.
                return
            }
        }
        guard searchID == latestSearchID else { return }

        state = FoodSearchState(query: trimmed, results: .loading)
        let results = await foodSearch.search(trimmed)
        guard searchID == latestSearchID, Task.isCancelled == false else { return }

        if let error = results.errorIfAllFailed {
            state.results = .failed(userMessage(for: error))
        } else {
            state.results = .loaded(results)
        }
    }
}
