import SwiftUI

/// One nutrient's name and formatted amount, or "—" when it's unknown.
struct NutrientRow: View {
    let nutrient: Nutrient
    let amount: Double?
    var isPartial = false

    var body: some View {
        LabeledContent {
            VStack(alignment: .trailing) {
                NutrientAmountText(amount: amount, unit: nutrient.unit)
                if isPartial {
                    Text(.partialLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } label: {
            Text(nutrient.title)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        NutrientRow(nutrient: .sodium, amount: 42.8)
        NutrientRow(nutrient: .vitaminD, amount: nil)
        NutrientRow(nutrient: .iron, amount: 1.2, isPartial: true)
    }
}
