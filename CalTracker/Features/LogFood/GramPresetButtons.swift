import SwiftUI

/// Quick-pick buttons that set a common amount, stacking vertically at accessibility text sizes.
struct GramPresetButtons: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var grams: Double

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading))
            : AnyLayout(HStackLayout())

        layout {
            ForEach(LogFoodViewModel.gramPresets, id: \.self) { preset in
                GramPresetButton(preset: preset, grams: $grams)
            }
        }
    }
}

#Preview {
    @Previewable @State var grams = 100.0
    Form {
        GramPresetButtons(grams: $grams)
    }
}
