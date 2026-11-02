import SwiftUI

/// Searches both food databases, loads more results as the person scrolls, and reports the chosen food.
struct FoodSearchView: View {
    /// Called when the person picks a result.
    let onSelect: (FoodItem) -> Void

    /// Called when the person taps Filters, with the view model the filters sheet applies its changes to.
    let onShowFilters: (FoodSearchViewModel) -> Void

    @State private var viewModel: FoodSearchViewModel
    @State private var query = ""

    /// Whether the search field is active. It's closed on selection, because an active field outlives a pop to Today.
    @State private var isSearchPresented = false

    /// Creates the screen for `viewModel`, reporting picks to `onSelect` and Filters taps to `onShowFilters`.
    init(
        viewModel: FoodSearchViewModel,
        onSelect: @escaping (FoodItem) -> Void,
        onShowFilters: @escaping (FoodSearchViewModel) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
        self.onShowFilters = onShowFilters
    }

    var body: some View {
        List {
            if case .loaded(let results) = viewModel.state.results, results.hasNoMatches == false {
                Section {
                    ForEach(results.failures) { failure in
                        SourceFailureRow(failure: failure)
                    }
                }
                Section {
                    ForEach(results.foods) { food in
                        FoodResultRow(food: food, onSelect: select)
                    }
                    if results.canLoadMore {
                        LoadMoreRow(
                            paging: viewModel.state.paging,
                            cursor: results.cursor,
                            onLoad: viewModel.loadMore,
                            onRetry: viewModel.retryLoadMore
                        )
                    }
                }
            }
        }
        .overlay {
            FoodSearchStatusView(
                state: viewModel.state,
                filtersActive: viewModel.filters.isActive,
                onClearFilters: viewModel.clearFilters
            )
        }
        .safeAreaBar(edge: .top) {
            FoodSearchFilterBar(filters: viewModel.filters, onShowFilters: showFilters)
        }
        .navigationTitle(.searchTitle)
        .searchable(
            text: $query,
            isPresented: $isSearchPresented,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: .searchPrompt
        )
        .autocorrectionDisabled()
        // A filter change searches the same text again, so it's part of the identity.
        .task(id: "\(viewModel.filtersRevision)|\(query)") {
            await viewModel.search(query)
        }
    }

    private func select(_ food: FoodItem) {
        isSearchPresented = false
        onSelect(food)
    }

    private func showFilters() {
        onShowFilters(viewModel)
    }
}

#Preview {
    NavigationStack {
        FoodSearchView(viewModel: AppDependencies.preview.makeSearchViewModel(), onSelect: { _ in }, onShowFilters: { _ in })
    }
}
