import SwiftUI

/// A sheet for narrowing Open Food Facts results by country and brand.
///
/// Changes are a draft until Done, so each round of edits triggers one search instead of one per tap.
struct FoodSearchFiltersView: View {
    @Environment(\.dismiss) private var dismiss

    /// The top brands for the current query.
    let brandOptions: [BrandOption]

    /// Called with the edited filters when the person taps Done.
    let onApply: (FoodSearchFilters) -> Void

    /// The brand filter in use when the sheet opened, offered in the picker even when it isn't a top brand.
    private let initialBrand: BrandFilter?

    @State private var regionEnabled: Bool
    @State private var regionCode: String?
    @State private var pickedBrand: BrandFilter?
    @State private var typedBrand = ""

    /// Creates a sheet that starts from `filters` and offers `brandOptions`.
    init(filters: FoodSearchFilters, brandOptions: [BrandOption], onApply: @escaping (FoodSearchFilters) -> Void) {
        self.brandOptions = brandOptions
        self.onApply = onApply
        initialBrand = filters.brand
        _regionEnabled = State(initialValue: filters.regionEnabled)
        _regionCode = State(initialValue: filters.regionCode)
        _pickedBrand = State(initialValue: filters.brand)
    }

    var body: some View {
        NavigationStack {
            Form {
                CountryFilterSection(isEnabled: $regionEnabled, regionCode: $regionCode)
                BrandFilterSection(brands: pickerBrands, pickedBrand: $pickedBrand, typedBrand: $typedBrand, onSubmit: apply)
            }
            .navigationTitle(.searchFiltersTitle)
            .navigationBarTitleDisplayMode(.inline)
            .sheetActions(confirm: .doneAction, action: apply)
        }
    }

    /// The top brands, plus the brand in use when it isn't one of them.
    private var pickerBrands: [BrandFilter] {
        var brands = brandOptions.map(\.filter)
        if let initialBrand, brands.contains(initialBrand) == false {
            brands.insert(initialBrand, at: 0)
        }
        return brands
    }

    /// Applies the draft. A typed brand wins over the picked one.
    private func apply() {
        let typed = typedBrand.trimmingCharacters(in: .whitespacesAndNewlines)
        onApply(FoodSearchFilters(
            regionEnabled: regionEnabled,
            regionCode: regionCode,
            brand: typed.isEmpty ? pickedBrand : .name(typed)
        ))
        dismiss()
    }
}

#Preview {
    FoodSearchFiltersView(
        filters: FoodSearchFilters(regionEnabled: true, regionCode: "IN", brand: .name("Karachi Bakery")),
        brandOptions: [BrandOption(tag: "parle", name: "Parle"), BrandOption(tag: "britannia", name: "Britannia")],
        onApply: { _ in }
    )
}
