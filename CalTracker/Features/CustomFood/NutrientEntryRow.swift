import SwiftUI

/// A form row for typing one nutrient's amount, with a menu for its unit when it can be typed in more than one.
struct NutrientEntryRow: View {
    /// The nutrient the row edits.
    let nutrient: Nutrient

    /// The draft that holds the amount and unit.
    @Binding var draft: CustomFoodDraft

    var body: some View {
        let units = nutrient.entryUnits

        LabeledContent {
            HStack {
                TextField(value: $draft[nutrient], format: .number) {
                    Text(nutrient.title)
                }
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)

                if units.count > 1 {
                    Picker(selection: $draft[unitOf: nutrient]) {
                        ForEach(units) { unit in
                            Text(verbatim: unit.symbol)
                                .tag(unit)
                        }
                    } label: {
                        Text(.customFoodUnitPicker(String(localized: nutrient.title)))
                    }
                    .pickerStyle(.menu)
                    // The row already names the nutrient, so the menu shows only the chosen unit.
                    .labelsHidden()
                    .fixedSize()
                } else {
                    Text(verbatim: draft[unitOf: nutrient].symbol)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
        } label: {
            Text(nutrient.title)
        }
    }
}

#Preview {
    @Previewable @State var draft = CustomFoodDraft(name: "Dal")
    Form {
        NutrientEntryRow(nutrient: .energy, draft: $draft)
        NutrientEntryRow(nutrient: .protein, draft: $draft)
        NutrientEntryRow(nutrient: .vitaminD, draft: $draft)
    }
}
