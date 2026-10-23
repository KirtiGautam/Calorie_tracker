import SwiftUI

/// A tappable search result showing the food's name, brand, source and energy per 100 g.
struct FoodResultRow: View {
    let food: FoodItem
    let onSelect: (FoodItem) -> Void

    var body: some View {
        Button(action: select) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.name)
                        .foregroundStyle(.primary)
                    if let brand = food.brand {
                        Text(brand)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    SourceBadge(source: food.source)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    NutrientAmountText(amount: food.per100g.energy, unit: .kilocalories)
                        .foregroundStyle(.primary)
                    Text(.per100Grams)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func select() {
        onSelect(food)
    }
}

#Preview {
    List {
        FoodResultRow(food: .previewBanana) { _ in }
        FoodResultRow(food: .previewNutella) { _ in }
    }
}
