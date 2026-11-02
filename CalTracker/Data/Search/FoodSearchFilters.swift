/// The filters that narrow a food search.
///
/// They apply only to Open Food Facts. USDA whole foods always appear, because USDA data is US-only and has no brands.
nonisolated struct FoodSearchFilters: Hashable, Sendable {
    /// Whether results are limited to products sold in `regionCode`.
    var regionEnabled = false

    /// The ISO 3166-1 region code to filter by, such as "IN". It's kept while the filter is off so it can be turned back on.
    var regionCode: String?

    /// The brand to limit results to, or `nil` for any brand.
    var brand: BrandFilter?

    /// The region code in effect: `regionCode` while the region filter is on, otherwise `nil`.
    var activeRegionCode: String? {
        regionEnabled ? regionCode : nil
    }

    /// Whether any filter narrows the results.
    var isActive: Bool {
        activeRegionCode != nil || brand != nil
    }
}
