/// A brand to limit Open Food Facts results to.
nonisolated enum BrandFilter: Hashable, Sendable {
    /// A brand picked from the top-brands list, by its Open Food Facts tag (such as "lay-s") and display name.
    case tag(String, name: String)

    /// A brand the person typed.
    case name(String)

    /// The brand as it's shown to the person.
    var displayName: String {
        switch self {
        case .tag(_, let name): name
        case .name(let name): name
        }
    }
}
