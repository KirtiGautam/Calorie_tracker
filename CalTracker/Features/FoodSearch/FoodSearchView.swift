import SwiftUI

/// Searches both food databases, loads more results as the person scrolls, and reports the chosen food.
///
/// Before a search starts it lists the foods the person logs most often, which can be logged again in one tap.
struct FoodSearchView: View {
    @Environment(\.calendar) private var calendar

    /// Called when the person picks a result.
    let onSelect: (FoodItem) -> Void

    /// Called when the person taps a frequent food's row, to log it after choosing the amount.
    let onSelectFrequent: (FrequentFood) -> Void

    /// Called after the person logs a frequent food with its + button.
    let onLogged: (LoggedFood) -> Void

    /// Called when the person taps Filters, with the view model the filters sheet applies its changes to.
    let onShowFilters: (FoodSearchViewModel) -> Void

    @State private var viewModel: FoodSearchViewModel
    @State private var frequentFoods: FrequentFoodsViewModel
    @State private var query = ""
    @State private var failureMessage: LocalizedStringResource?

    /// Whether the search field is active. It's closed on selection, because an active field outlives a pop to Today.
    @State private var isSearchPresented = false

    /// Creates the screen for `viewModel` and `frequentFoods`.
    ///
    /// - Parameters:
    ///   - viewModel: Searches the food databases.
    ///   - frequentFoods: Lists the foods the person logs most often, before a search starts.
    ///   - onSelect: Called when the person picks a search result.
    ///   - onSelectFrequent: Called when the person taps a frequent food's row.
    ///   - onLogged: Called after the person logs a frequent food with its + button.
    ///   - onShowFilters: Called when the person taps Filters.
    init(
        viewModel: FoodSearchViewModel,
        frequentFoods: FrequentFoodsViewModel,
        onSelect: @escaping (FoodItem) -> Void,
        onSelectFrequent: @escaping (FrequentFood) -> Void,
        onLogged: @escaping (LoggedFood) -> Void,
        onShowFilters: @escaping (FoodSearchViewModel) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        _frequentFoods = State(initialValue: frequentFoods)
        self.onSelect = onSelect
        self.onSelectFrequent = onSelectFrequent
        self.onLogged = onLogged
        self.onShowFilters = onShowFilters
    }

    var body: some View {
        let showsFrequentFoods = viewModel.state.results.isIdle && frequentFoods.hasContent

        List {
            if showsFrequentFoods {
                FrequentFoodsSection(
                    frequentFoods: frequentFoods.frequentFoods,
                    failure: frequentFoods.loadFailure,
                    onSelect: selectFrequent,
                    onQuickLog: quickLog
                )
            }
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
                onClearFilters: viewModel.clearFilters,
                showsIdleMessage: showsFrequentFoods == false
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
        // The screen is pushed fresh for every visit and every log pops it, so loading once keeps the list current.
        .task {
            loadFrequentFoods()
        }
        .errorAlert(.logFailedTitle, message: $failureMessage)
    }

    private func select(_ food: FoodItem) {
        isSearchPresented = false
        onSelect(food)
    }

    private func selectFrequent(_ frequentFood: FrequentFood) {
        isSearchPresented = false
        onSelectFrequent(frequentFood)
    }

    private func quickLog(_ frequentFood: FrequentFood) {
        do {
            let loggedFood = try frequentFoods.quickLog(frequentFood)
            isSearchPresented = false
            onLogged(loggedFood)
        } catch {
            failureMessage = userMessage(for: error)
        }
    }

    private func loadFrequentFoods() {
        frequentFoods.load(now: .now, calendar: calendar)
    }

    private func showFilters() {
        onShowFilters(viewModel)
    }
}

#Preview {
    NavigationStack {
        FoodSearchView(
            viewModel: AppDependencies.preview.makeSearchViewModel(),
            frequentFoods: AppDependencies.preview.makeFrequentFoodsViewModel(),
            onSelect: { _ in },
            onSelectFrequent: { _ in },
            onLogged: { _ in },
            onShowFilters: { _ in }
        )
    }
}
