import SwiftUI

/// The foods the person logs most often, listed on the search screen before they search.
struct FrequentFoodsSection: View {
    /// The foods to list, most frequent first.
    let frequentFoods: [FrequentFood]

    /// Why the foods couldn't be loaded, shown in place of them, or `nil` when they loaded.
    let failure: LocalizedStringResource?

    /// Called when the person taps a food's row, to choose the amount before logging.
    let onSelect: (FrequentFood) -> Void

    /// Called when the person taps a food's +, to log the last amount right away.
    let onQuickLog: (FrequentFood) -> Void

    var body: some View {
        Section {
            if let failure {
                Text(failure)
                    .foregroundStyle(.secondary)
            }
            ForEach(frequentFoods) { frequentFood in
                FrequentFoodRow(frequentFood: frequentFood, onSelect: onSelect, onQuickLog: onQuickLog)
            }
        } header: {
            Text(.frequentSection)
        }
    }
}

#Preview {
    List {
        FrequentFoodsSection(
            frequentFoods: [
                FrequentFood(food: .previewBanana, grams: 120),
                FrequentFood(food: .previewNutella, grams: 15),
            ],
            failure: nil,
            onSelect: { _ in },
            onQuickLog: { _ in }
        )
    }
}
