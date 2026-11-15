import SwiftUI

/// A food the person logs often: tap the row to choose the amount, or tap + to log the last amount right away.
struct FrequentFoodRow: View {
    /// The food and the amount logged last time.
    let frequentFood: FrequentFood

    /// Called with `frequentFood` when the person taps the row, to open the log sheet at the last amount.
    let onSelect: (FrequentFood) -> Void

    /// Called with `frequentFood` when the person taps +, to log the last amount without the sheet.
    let onQuickLog: (FrequentFood) -> Void

    var body: some View {
        let amount = NutrientUnit.grams.formatted(frequentFood.grams)

        HStack(spacing: 12) {
            Button(action: select) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading) {
                        Text(frequentFood.food.name)
                            .foregroundStyle(.primary)
                        if let brand = frequentFood.food.brand {
                            Text(brand)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        NutrientAmountText(amount: frequentFood.grams, unit: .grams)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    NutrientAmountText(amount: frequentFood.nutrients.energy, unit: .kilocalories)
                        .foregroundStyle(.primary)
                }
                .contentShape(.rect)
            }
            // With the default style, a List row runs every button in it on any tap, so both buttons opt out.
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)

            Button(.quickLogAction(amount, frequentFood.food.name), systemImage: "plus.circle.fill", action: quickLog)
                .labelStyle(.iconOnly)
                .font(.title2)
                .buttonStyle(.borderless)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
                .accessibilityIdentifier("quickLog")
        }
    }

    private func select() {
        onSelect(frequentFood)
    }

    private func quickLog() {
        onQuickLog(frequentFood)
    }
}

#Preview {
    List {
        FrequentFoodRow(frequentFood: FrequentFood(food: .previewBanana, grams: 120), onSelect: { _ in }, onQuickLog: { _ in })
        FrequentFoodRow(frequentFood: FrequentFood(food: .previewNutella, grams: 15), onSelect: { _ in }, onQuickLog: { _ in })
    }
}
