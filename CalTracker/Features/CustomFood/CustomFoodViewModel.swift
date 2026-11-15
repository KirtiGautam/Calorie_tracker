import Foundation
import Observation

/// Holds a custom food as the person types it, previews it per 100 g, and saves it.
@Observable
final class CustomFoodViewModel {
    /// The food being entered.
    var draft: CustomFoodDraft

    @ObservationIgnored private let store: any CustomFoodStoring

    /// Creates a view model that saves through `store`, with the name starting as `name`.
    init(store: any CustomFoodStoring, name: String = "") {
        self.store = store
        draft = CustomFoodDraft(name: name)
    }

    /// The draft's nutrients per 100 g, or `nil` while it can't be standardized.
    var preview: NutrientProfile? {
        try? draft.per100g()
    }

    /// The nutrients the preview lists: every macro, and each micronutrient the person filled in.
    var previewNutrients: [Nutrient] {
        Nutrient.allCases.filter { $0.group == .macro || draft[$0] != nil }
    }

    /// Why the values can't be standardized, or `nil` when they can or nothing has been typed yet.
    ///
    /// A blank name isn't reported here, because the empty name field already shows it.
    var issue: LocalizedStringResource? {
        guard draft.hasAmounts else { return nil }
        do {
            _ = try draft.per100g()
            return nil
        } catch {
            return userMessage(for: error)
        }
    }

    /// Whether the draft has a name and values that can be standardized.
    var canSave: Bool {
        draft.trimmedName.isEmpty == false && preview != nil
    }

    /// Standardizes the draft and saves it.
    ///
    /// - Returns: The saved food, ready to log.
    /// - Throws: A `CustomFoodError` when the draft can't be standardized, or the store's save error.
    func save() throws -> CustomFoodRecord {
        let record = try draft.standardized()
        try store.save(record)
        return record
    }
}
