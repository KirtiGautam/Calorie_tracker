import SwiftUI

/// One nutrient's target amount, with its unit after the field.
struct TargetField: View {
    let nutrient: Nutrient
    @Binding var value: Double?

    var body: some View {
        LabeledContent {
            HStack {
                TextField(value: $value, format: .number) {
                    Text(nutrient.title)
                }
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                Text(nutrient.unit.symbol)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        } label: {
            Text(nutrient.title)
        }
    }
}

#Preview {
    @Previewable @State var value: Double? = 150
    Form {
        TargetField(nutrient: .protein, value: $value)
    }
}
