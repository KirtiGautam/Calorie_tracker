import SwiftUI

/// A collapsible list of today's micronutrient totals.
struct MicronutrientDisclosure: View {
    let totals: DailyTotals

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            NutrientTable(
                profile: totals.profile,
                nutrients: Nutrient.micros,
                partialNutrients: totals.partialNutrients
            )
        } label: {
            Text(.micronutrientsTitle)
        }
    }
}

#Preview {
    List {
        MicronutrientDisclosure(totals: DailyTotals(entries: [FoodItem.previewBanana.per100g, FoodItem.previewNutella.per100g]))
    }
}
