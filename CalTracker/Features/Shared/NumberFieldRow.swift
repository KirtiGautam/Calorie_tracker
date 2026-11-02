import SwiftUI

/// A form row with a title and a right-aligned number field, optionally followed by its unit.
struct NumberFieldRow: View {
    /// The row's title, which also labels the field.
    let title: LocalizedStringResource

    /// The keyboard the field shows.
    let keyboard: UIKeyboardType

    /// The unit shown after the field, such as "g", or `nil` for none.
    let unit: String?

    /// The field, built once by the initializer for its value type.
    private let field: TextField<Text>

    /// Creates a row whose field edits a value that's always present.
    init<Format: ParseableFormatStyle>(
        _ title: LocalizedStringResource,
        value: Binding<Format.FormatInput>,
        format: Format,
        keyboard: UIKeyboardType = .decimalPad,
        unit: String? = nil
    ) where Format.FormatOutput == String {
        self.title = title
        self.keyboard = keyboard
        self.unit = unit
        field = TextField(value: value, format: format) { Text(title) }
    }

    /// Creates a row whose field edits a value that's `nil` while the field is empty.
    init<Format: ParseableFormatStyle>(
        _ title: LocalizedStringResource,
        value: Binding<Format.FormatInput?>,
        format: Format,
        keyboard: UIKeyboardType = .decimalPad,
        unit: String? = nil
    ) where Format.FormatOutput == String {
        self.title = title
        self.keyboard = keyboard
        self.unit = unit
        field = TextField(value: value, format: format) { Text(title) }
    }

    var body: some View {
        LabeledContent {
            HStack {
                field
                    .keyboardType(keyboard)
                    .multilineTextAlignment(.trailing)
                if let unit {
                    Text(unit)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
        } label: {
            Text(title)
        }
    }
}

#Preview {
    @Previewable @State var grams = 150.0
    @Previewable @State var age: Int?
    @Previewable @State var protein: Double? = 112
    Form {
        NumberFieldRow(.gramsField, value: $grams, format: .number)
        NumberFieldRow(.ageField, value: $age, format: .number, keyboard: .numberPad)
        NumberFieldRow(Nutrient.protein.title, value: $protein, format: .number, unit: NutrientUnit.grams.symbol)
    }
}
