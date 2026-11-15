import SwiftUI

/// Searches both food databases, loads more results as the person scrolls, and reports the chosen food.
///
/// Before a search starts it lists the foods the person logs most often, which can be logged again in one tap, and
/// the foods they entered themselves. During a search, their own foods that match come first. When nothing fits, the
/// person can enter the food themselves.
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

    /// Called when the person taps one of their own foods, to log it after choosing the amount.
    let onSelectCustom: (CustomFoodRecord) -> Void

    /// Called when the person asks to add a custom food, with the search text to start its name from and the list
    /// to reload once it's saved.
    let onAddCustomFood: (String, CustomFoodsViewModel) -> Void

    @State private var viewModel: FoodSearchViewModel
    @State private var frequentFoods: FrequentFoodsViewModel
    @State private var customFoods: CustomFoodsViewModel
    @State private var query = ""
    @State private var failureMessage: LocalizedStringResource?
    @State private var deleteFailureMessage: LocalizedStringResource?

    /// Whether the search field is active. It's closed on selection, because an active field outlives a pop to Today.
    @State private var isSearchPresented = false

    /// Creates the screen for `viewModel`, `frequentFoods` and `customFoods`.
    ///
    /// - Parameters:
    ///   - viewModel: Searches the food databases.
    ///   - frequentFoods: Lists the foods the person logs most often, before a search starts.
    ///   - customFoods: Lists the foods the person entered themselves that match the search.
    ///   - onSelect: Called when the person picks a search result.
    ///   - onSelectFrequent: Called when the person taps a frequent food's row.
    ///   - onLogged: Called after the person logs a frequent food with its + button.
    ///   - onShowFilters: Called when the person taps Filters.
    ///   - onSelectCustom: Called when the person taps one of their own foods.
    ///   - onAddCustomFood: Called when the person asks to add a custom food.
    init(
        viewModel: FoodSearchViewModel,
        frequentFoods: FrequentFoodsViewModel,
        customFoods: CustomFoodsViewModel,
        onSelect: @escaping (FoodItem) -> Void,
        onSelectFrequent: @escaping (FrequentFood) -> Void,
        onLogged: @escaping (LoggedFood) -> Void,
        onShowFilters: @escaping (FoodSearchViewModel) -> Void,
        onSelectCustom: @escaping (CustomFoodRecord) -> Void,
        onAddCustomFood: @escaping (String, CustomFoodsViewModel) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        _frequentFoods = State(initialValue: frequentFoods)
        _customFoods = State(initialValue: customFoods)
        self.onSelect = onSelect
        self.onSelectFrequent = onSelectFrequent
        self.onLogged = onLogged
        self.onShowFilters = onShowFilters
        self.onSelectCustom = onSelectCustom
        self.onAddCustomFood = onAddCustomFood
    }

    var body: some View {
        let showsFrequentFoods = viewModel.state.results.isIdle && frequentFoods.hasContent
        // With the person's own foods on screen, a centred overlay would cover them, so the status becomes a row.
        let showsStatusInList = customFoods.hasContent

        List {
            if showsFrequentFoods {
                FrequentFoodsSection(
                    frequentFoods: frequentFoods.frequentFoods,
                    failure: frequentFoods.loadFailure,
                    onSelect: selectFrequent,
                    onQuickLog: quickLog
                )
            }
            if customFoods.hasContent {
                CustomFoodsSection(
                    foods: customFoods.foods,
                    failure: customFoods.loadFailure,
                    onSelect: selectCustom,
                    onDelete: deleteCustom
                )
            }
            if showsStatusInList {
                Section {
                    statusView(showsIdleMessage: false)
                }
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
            if showsStatusInList == false {
                statusView(showsIdleMessage: showsFrequentFoods == false)
            }
        }
        .safeAreaBar(edge: .top) {
            FoodSearchFilterBar(filters: viewModel.filters, onShowFilters: showFilters, onAddCustomFood: addCustomFood)
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
        // The person's own foods are on the device, so they're matched on every keystroke without a debounce.
        .onChange(of: query, initial: true) { _, newQuery in
            loadCustomFoods(matching: newQuery)
        }
        .errorAlert(.logFailedTitle, message: $failureMessage)
        .errorAlert(.customFoodDeleteFailedTitle, message: $deleteFailureMessage)
    }

    /// The status of the database search, for the overlay or a row in the list.
    private func statusView(showsIdleMessage: Bool) -> FoodSearchStatusView {
        FoodSearchStatusView(
            state: viewModel.state,
            filtersActive: viewModel.filters.isActive,
            onClearFilters: viewModel.clearFilters,
            onAddCustomFood: addCustomFood,
            showsIdleMessage: showsIdleMessage
        )
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

    private func loadCustomFoods(matching query: String) {
        customFoods.load(matching: query)
    }

    private func selectCustom(_ record: CustomFoodRecord) {
        isSearchPresented = false
        onSelectCustom(record)
    }

    private func deleteCustom(_ record: CustomFoodRecord) {
        do {
            try customFoods.delete(record)
        } catch {
            deleteFailureMessage = userMessage(for: error)
        }
    }

    /// Asks to add a custom food, starting its name from the search text.
    private func addCustomFood() {
        isSearchPresented = false
        onAddCustomFood(query.trimmingCharacters(in: .whitespacesAndNewlines), customFoods)
    }
}

#Preview {
    NavigationStack {
        FoodSearchView(
            viewModel: AppDependencies.preview.makeSearchViewModel(),
            frequentFoods: AppDependencies.preview.makeFrequentFoodsViewModel(),
            customFoods: AppDependencies.preview.makeCustomFoodsViewModel(),
            onSelect: { _ in },
            onSelectFrequent: { _ in },
            onLogged: { _ in },
            onShowFilters: { _ in },
            onSelectCustom: { _ in },
            onAddCustomFood: { _, _ in }
        )
    }
}
