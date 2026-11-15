import SwiftUI

/// The bar above the search results that opens the filters, shows which ones are on, and adds a custom food.
///
/// It sits below the search field rather than in the toolbar, because iOS hides toolbar items while the field is active.
struct FoodSearchFilterBar: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The filters in use.
    let filters: FoodSearchFilters

    /// Opens the filters sheet.
    let onShowFilters: () -> Void

    /// Opens the sheet for entering a custom food.
    let onAddCustomFood: () -> Void

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))

        layout {
            Button(action: onShowFilters) {
                HStack(spacing: 8) {
                    Label {
                        Text(.searchFiltersAction)
                    } icon: {
                        Image(systemName: filters.isActive
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle")
                    }
                    // The filter names give way first when space runs out, so "Filters" always shows in full.
                    Group {
                        if let regionCode = filters.activeRegionCode {
                            Text(locale.countryName(forRegionCode: regionCode))
                        }
                        if let brand = filters.brand {
                            Text(brand.displayName)
                        }
                    }
                    .foregroundStyle(.secondary)
                    .layoutPriority(-1)
                }
                .lineLimit(1)
            }
            .accessibilityIdentifier("searchFilters")

            Button(.customFoodBarAction, systemImage: "plus", action: onAddCustomFood)
                .lineLimit(1)
                .layoutPriority(1)
                .accessibilityLabel(Text(.addCustomFoodAction))
                .accessibilityIdentifier("addCustomFood")
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

#Preview {
    VStack {
        FoodSearchFilterBar(filters: FoodSearchFilters(), onShowFilters: {}, onAddCustomFood: {})
        FoodSearchFilterBar(
            filters: FoodSearchFilters(regionEnabled: true, regionCode: "IN", brand: .name("Karachi Bakery")),
            onShowFilters: {},
            onAddCustomFood: {}
        )
    }
}
