import SwiftUI

/// One quick-pick amount button.
struct GramPresetButton: View {
    let preset: Double
    @Binding var grams: Double

    var body: some View {
        // A bordered style keeps each button separately tappable inside a Form row.
        Button(action: choose) {
            Text(verbatim: NutrientUnit.grams.formatted(preset))
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(Text(verbatim: NutrientUnit.grams.formatted(preset, spelledOut: true)))
        .accessibilityAddTraits(grams == preset ? .isSelected : [])
    }

    private func choose() {
        grams = preset
    }
}

#Preview {
    @Previewable @State var grams = 100.0
    GramPresetButton(preset: 50, grams: $grams)
}
