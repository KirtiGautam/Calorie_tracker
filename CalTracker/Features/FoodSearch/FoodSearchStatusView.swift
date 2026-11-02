import SwiftUI

/// The overlay shown over the results list when there's nothing to list yet.
struct FoodSearchStatusView: View {
    /// What the search screen shows.
    let state: FoodSearchState

    /// Whether a country or brand filter narrows the results, which changes the empty state.
    var filtersActive = false

    /// Turns the filters off from the empty state.
    var onClearFilters: () -> Void = {}

    var body: some View {
        switch state.results {
        case .idle:
            ContentUnavailableView {
                Label {
                    Text(.searchIdleTitle)
                } icon: {
                    Image(systemName: "magnifyingglass")
                }
            } description: {
                Text(.searchIdleMessage)
            }
        case .loading:
            ProgressView()
        case .failed(let message):
            ContentUnavailableView {
                Label {
                    Text(.searchFailedTitle)
                } icon: {
                    Image(systemName: "wifi.exclamationmark")
                }
            } description: {
                Text(message)
            }
        case .loaded(let results) where results.hasNoMatches && filtersActive:
            ContentUnavailableView {
                Label {
                    Text(.searchFilteredEmptyTitle)
                } icon: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            } description: {
                Text(.searchFilteredEmptyMessage(state.query))
            } actions: {
                Button(.clearFiltersAction, action: onClearFilters)
            }
        case .loaded(let results) where results.hasNoMatches:
            ContentUnavailableView.search(text: state.query)
        case .loaded:
            EmptyView()
        }
    }
}

#Preview {
    FoodSearchStatusView(state: FoodSearchState(query: "", results: .idle))
}
