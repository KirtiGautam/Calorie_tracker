import SwiftUI

/// Editable daily targets for the headline macros.
struct TargetFieldsSection: View {
    /// The targets being edited.
    @Binding var targets: DailyTargets

    var body: some View {
        Section {
            ForEach(Nutrient.macros) { nutrient in
                NumberFieldRow(nutrient.title, value: $targets[nutrient], format: .number, unit: nutrient.unit.symbol)
            }
        } header: {
            Text(.targetsSection)
        } footer: {
            Text(.targetsFooter)
        }
    }
}

#Preview {
    @Previewable @State var targets = DailyTargets(energy: 2_560, protein: 112, carbohydrates: 368, fat: 71)
    Form {
        TargetFieldsSection(targets: $targets)
    }
}
