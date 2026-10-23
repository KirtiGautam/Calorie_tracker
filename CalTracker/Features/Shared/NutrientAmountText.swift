import SwiftUI

/// A formatted nutrient amount with its unit, or "—" with a spoken "Unknown" label when there's no value.
struct NutrientAmountText: View {
    let amount: Double?
    let unit: NutrientUnit

    var body: some View {
        if let amount {
            Text(verbatim: unit.formatted(amount))
                .contentTransition(.numericText())
                .accessibilityLabel(Text(verbatim: unit.formatted(amount, spelledOut: true)))
        } else {
            Text(verbatim: "—")
                .accessibilityLabel(Text(.unknownValue))
        }
    }
}
