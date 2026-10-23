import SwiftUI

/// One macro's name and total, marked partial when some entries didn't report it, with progress toward its target.
struct MacroValue: View {
    let nutrient: Nutrient
    let totals: DailyTotals
    var progress: TargetProgress?
    var isProminent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(nutrient.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            NutrientAmountText(amount: totals.profile[nutrient], unit: nutrient.unit)
                .font(isProminent ? .largeTitle.bold() : .title3.bold())
            if totals.isPartial(nutrient) {
                Text(.partialLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let progress {
                TargetProgressBar(progress: progress)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    MacroValue(
        nutrient: .energy,
        totals: DailyTotals(entries: []),
        progress: TargetProgress(nutrient: .energy, total: 0, target: 2_000),
        isProminent: true
    )
}
