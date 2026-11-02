import SwiftUI

/// The row at the end of the results: a spinner that loads the next page when it comes into view, or the last
/// page's error with a button to try again.
struct LoadMoreRow: View {
    /// Whether a page is loading or failed.
    let paging: FoodSearchPaging

    /// The next page from each source. A new cursor loads again while the row is still on screen.
    let cursor: FoodSearchCursor

    /// Loads the next page. It runs in a task that's cancelled when the row scrolls away.
    let onLoad: () async -> Void

    /// Clears the failure so the page loads again.
    let onRetry: () -> Void

    var body: some View {
        switch paging {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .accessibilityLabel(Text(.searchLoadingMore))
                .task(id: cursor) {
                    await onLoad()
                }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text(message)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
                .foregroundStyle(.secondary)
                Button(.tryAgainAction, action: onRetry)
            }
        }
    }
}

#Preview {
    List {
        LoadMoreRow(paging: .loading, cursor: .firstPage, onLoad: {}, onRetry: {})
        LoadMoreRow(paging: .failed(.errorOffline), cursor: .firstPage, onLoad: {}, onRetry: {})
    }
}
