import SwiftUI

/// What the search screen shows when the databases have nothing to list yet: a prompt, progress, or why there are
/// no results, with a way to add the food yourself.
///
/// It's an overlay over the empty results list, or a row in the list when the person's own foods fill it.
struct FoodSearchStatusView: View {
    /// What the search screen shows.
    let state: FoodSearchState

    /// Whether a country or brand filter narrows the results, which changes the empty state.
    var filtersActive = false

    /// Turns the filters off from the empty state.
    var onClearFilters: () -> Void = {}

    /// Opens the sheet for entering a custom food, from the empty and failed states.
    var onAddCustomFood: () -> Void = {}

    /// Whether to prompt for a search before one starts. It's off while other sections fill the list instead.
    var showsIdleMessage = true

    var body: some View {
        switch state.results {
        case .idle where showsIdleMessage:
            ContentUnavailableView {
                Label {
                    Text(.searchIdleTitle)
                } icon: {
                    Image(systemName: "magnifyingglass")
                }
            } description: {
                Text(.searchIdleMessage)
            }
        case .idle:
            EmptyView()
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label {
                    Text(.searchFailedTitle)
                } icon: {
                    Image(systemName: "wifi.exclamationmark")
                }
            } description: {
                Text(message)
            } actions: {
                Button(.addCustomFoodAction, systemImage: "plus", action: onAddCustomFood)
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
                Button(.addCustomFoodAction, systemImage: "plus", action: onAddCustomFood)
            }
        case .loaded(let results) where results.hasNoMatches:
            // Like `ContentUnavailableView.search(text:)`, which can't offer an action.
            ContentUnavailableView {
                Label {
                    Text(.searchNoResultsTitle)
                } icon: {
                    Image(systemName: "magnifyingglass")
                }
            } description: {
                Text(.searchNoResultsMessage(state.query))
            } actions: {
                Button(.addCustomFoodAction, systemImage: "plus", action: onAddCustomFood)
            }
        case .loaded:
            EmptyView()
        }
    }
}

#Preview {
    FoodSearchStatusView(state: FoodSearchState(query: "", results: .idle))
}
