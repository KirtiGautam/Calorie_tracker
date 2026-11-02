import Foundation

/// Where loading the next page of results stands.
enum FoodSearchPaging {
    /// No page is loading. The next one loads when the end of the list comes into view.
    case idle

    /// The next page is loading.
    case loading

    /// The last page failed to load, with a message ready to show the person. It's only tried again on request.
    case failed(LocalizedStringResource)
}
