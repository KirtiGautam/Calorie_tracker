import SwiftUI

/// A formatted nutrient amount with its unit, or "—" with a spoken "Unknown" label when there's no value.
struct NutrientAmountText: View {
    /// The amount in `unit`, or `nil` when it's unknown.
    let amount: Double?
    /// The unit `amount` is in.
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
