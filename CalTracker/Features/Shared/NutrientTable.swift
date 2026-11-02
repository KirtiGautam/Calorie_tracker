import SwiftUI

/// Rows for a list of nutrients, for use inside a `List` or `Form` section.
struct NutrientTable: View {
    /// The amounts to show.
    let profile: NutrientProfile
    /// The nutrients to list, in order.
    var nutrients = Nutrient.allCases
    /// The nutrients whose amounts undercount because some entries didn't report them.
    var partialNutrients: Set<Nutrient> = []

    var body: some View {
        ForEach(nutrients) { nutrient in
            NutrientRow(
                nutrient: nutrient,
                amount: profile[nutrient],
                isPartial: partialNutrients.contains(nutrient)
            )
        }
    }
}

#Preview {
    List {
        NutrientTable(profile: NutrientProfile(energy: 89, protein: 1.1, carbohydrates: 22.8, fat: 0.3, potassium: 358))
    }
}
