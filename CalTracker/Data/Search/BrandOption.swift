/// One of the most common brands for a search, offered as a brand filter.
nonisolated struct BrandOption: Identifiable, Hashable, Sendable {
    /// The Open Food Facts brand tag, such as "lay-s".
    let tag: String

    /// The brand as it's shown to the person, such as "Lay's".
    let name: String

    /// The stable identity of the brand: its tag.
    var id: String { tag }

    /// The filter that selects this brand.
    var filter: BrandFilter {
        .tag(tag, name: name)
    }
}
