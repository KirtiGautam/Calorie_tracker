import SwiftUI

/// Searches both food databases and reports the chosen food.
struct FoodSearchView: View {
    /// Called when the person picks a result.
    let onSelect: (FoodItem) -> Void

    @State private var viewModel: FoodSearchViewModel
    @State private var query = ""

    /// Whether the search field is active. It's closed on selection, because an active field outlives a pop to Today.
    @State private var isSearchPresented = false

    init(viewModel: FoodSearchViewModel, onSelect: @escaping (FoodItem) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
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
                }
            }
        }
        .overlay {
            FoodSearchStatusView(state: viewModel.state)
        }
        .navigationTitle(.searchTitle)
        .searchable(
            text: $query,
            isPresented: $isSearchPresented,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: .searchPrompt
        )
        .autocorrectionDisabled()
        .task(id: query) {
            await viewModel.search(query)
        }
    }

    private func select(_ food: FoodItem) {
        isSearchPresented = false
        onSelect(food)
    }
}

#Preview {
    NavigationStack {
        FoodSearchView(viewModel: AppDependencies.preview.makeSearchViewModel()) { _ in }
    }
}
