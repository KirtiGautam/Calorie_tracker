import SwiftUI

/// The bar above the search results that opens the filters and shows which ones are on.
///
/// It sits below the search field rather than in the toolbar, because iOS hides toolbar items while the field is active.
struct FoodSearchFilterBar: View {
    /// The filters in use.
    let filters: FoodSearchFilters

    /// Opens the filters sheet.
    let onShowFilters: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
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
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .accessibilityIdentifier("searchFilters")
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

#Preview {
    VStack {
        FoodSearchFilterBar(filters: FoodSearchFilters(), onShowFilters: {})
        FoodSearchFilterBar(
            filters: FoodSearchFilters(regionEnabled: true, regionCode: "IN", brand: .name("Karachi Bakery")),
            onShowFilters: {}
        )
    }
}
