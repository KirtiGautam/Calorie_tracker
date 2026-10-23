import SwiftUI

/// Editable daily targets for the headline macros.
struct TargetFieldsSection: View {
    @Binding var targets: DailyTargets

    var body: some View {
        Section {
            ForEach(Nutrient.macros) { nutrient in
                TargetField(nutrient: nutrient, value: $targets[nutrient])
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
