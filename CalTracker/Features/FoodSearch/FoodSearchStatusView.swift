import SwiftUI

/// The overlay shown over the results list when there's nothing to list yet.
struct FoodSearchStatusView: View {
    let state: FoodSearchState

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
