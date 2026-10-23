import SwiftUI

/// One logged food with its amount and energy.
struct LogEntryRow: View {
    let entry: FoodLogEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading) {
                Text(entry.name)
                if let brand = entry.brand {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                NutrientAmountText(amount: entry.grams, unit: .grams)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            NutrientAmountText(amount: entry.nutrients.energy, unit: .kilocalories)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        LogEntryRow(entry: FoodLogEntry(food: .previewBanana, grams: 150, loggedAt: .now))
    }
    .modelContainer(AppModelContainer.preview)
}
