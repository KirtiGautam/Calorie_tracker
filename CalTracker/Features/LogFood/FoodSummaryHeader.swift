import SwiftUI

/// The food's name, brand and source at the top of the log sheet.
struct FoodSummaryHeader: View {
    let food: FoodItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(food.name)
                .font(.headline)
            if let brand = food.brand {
                Text(brand)
                    .foregroundStyle(.secondary)
            }
            SourceBadge(source: food.source)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        FoodSummaryHeader(food: .previewNutella)
    }
}
