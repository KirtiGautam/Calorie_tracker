import SwiftUI

/// Today's energy with protein, carbohydrates and fat beneath it, each with progress toward its target.
struct DailyTotalsCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let totals: DailyTotals
    var targets = DailyTargets()

    /// The goal badge shown beside energy, or `nil` for none.
    var goal: WeightGoal?

    var body: some View {
        // Stack vertically at accessibility sizes so long names and values never truncate.
        let macroLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
        let energyLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))

        VStack(alignment: .leading, spacing: 12) {
            energyLayout {
                MacroValue(
                    nutrient: .energy,
                    totals: totals,
                    progress: targets.progress(for: .energy, in: totals),
                    isProminent: true
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                if let goal {
                    GoalBadge(goal: goal)
                }
            }

            macroLayout {
                ForEach([Nutrient.protein, .carbohydrates, .fat]) { nutrient in
                    MacroValue(nutrient: nutrient, totals: totals, progress: targets.progress(for: nutrient, in: totals))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

#Preview {
    List {
        DailyTotalsCard(
            totals: DailyTotals(entries: [FoodItem.previewBanana.per100g.scaled(byGrams: 150)]),
            targets: DailyTargets(energy: 2_560, protein: 112, carbohydrates: 30, fat: 71),
            goal: .cut
        )
    }
}
