import Foundation
import Observation

/// Lists the foods the person entered themselves that match the search, and deletes them.
@Observable
final class CustomFoodsViewModel {
    /// The matching foods, newest first.
    private(set) var foods: [CustomFoodRecord] = []

    /// Why the foods couldn't be loaded, or `nil` when they loaded or haven't been asked for.
    private(set) var loadFailure: LocalizedStringResource?

    /// Whether there's anything to show: some foods, or why they couldn't be loaded.
    var hasContent: Bool {
        foods.isEmpty == false || loadFailure != nil
    }

    @ObservationIgnored private let store: any CustomFoodStoring

    /// The search text the foods were last loaded for.
    @ObservationIgnored private var query = ""

    /// Creates a view model that reads and deletes through `store`.
    init(store: any CustomFoodStoring) {
        self.store = store
    }

    /// Loads the foods whose names contain `query`, or every food when it's blank.
    func load(matching query: String) {
        self.query = query
        reload()
    }

    /// Loads the foods again for the last query, such as after one was added.
    func reload() {
        do {
            foods = try store.foods(matching: query)
            loadFailure = nil
        } catch {
            foods = []
            loadFailure = userMessage(for: error)
        }
    }

    /// Deletes `record` and loads the list again.
    ///
    /// - Throws: The store's error when the food can't be deleted. The list is left as it was.
    func delete(_ record: CustomFoodRecord) throws {
        try store.delete(id: record.id)
        reload()
    }
}
