import SwiftUI

/// The person's own foods on the search screen: all of them before a search, and the ones that match during one.
struct CustomFoodsSection: View {
    /// The foods to list, newest first.
    let foods: [CustomFoodRecord]

    /// Why the foods couldn't be loaded, shown in place of them, or `nil` when they loaded.
    let failure: LocalizedStringResource?

    /// Called when the person taps a food, to choose the amount before logging.
    let onSelect: (CustomFoodRecord) -> Void

    /// Called when the person swipes a food away.
    let onDelete: (CustomFoodRecord) -> Void

    var body: some View {
        Section {
            if let failure {
                Text(failure)
                    .foregroundStyle(.secondary)
            }
            ForEach(foods) { record in
                FoodResultRow(food: record.food) { _ in
                    onSelect(record)
                }
            }
            .onDelete(perform: delete)
        } header: {
            Text(.customFoodsSection)
        }
    }

    private func delete(at offsets: IndexSet) {
        for record in offsets.map({ foods[$0] }) {
            onDelete(record)
        }
    }
}

#Preview {
    List {
        CustomFoodsSection(
            foods: [CustomFoodRecord(
                food: FoodItem(
                    id: "cus-1",
                    name: "Grandma's dal",
                    brand: nil,
                    source: .custom,
                    per100g: NutrientProfile(energy: 120, protein: 6, carbohydrates: 15, fat: 4)
                ),
                servingGrams: 350
            )],
            failure: nil,
            onSelect: { _ in },
            onDelete: { _ in }
        )
    }
}
