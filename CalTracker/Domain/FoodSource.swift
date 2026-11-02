import Foundation

/// The database a food came from.
///
/// The cases are in the order results and failures are listed.
nonisolated enum FoodSource: String, CaseIterable, Codable, Hashable, Sendable {
    case usda
    case openFoodFacts

    /// Returns the source of the food with the source-prefixed `foodID`, or `nil` when no source uses its prefix.
    init?(foodID: String) {
        guard let source = Self.allCases.first(where: { foodID.hasPrefix($0.idPrefix) }) else { return nil }
        self = source
    }

    /// The localized source name shown in badges.
    var title: LocalizedStringResource {
        switch self {
        case .usda: .sourceUSDA
        case .openFoodFacts: .sourceOpenFoodFacts
        }
    }

    /// The prefix on the IDs of this source's foods, such as `usda-` in `usda-173944`.
    var idPrefix: String {
        switch self {
        case .usda: "usda-"
        case .openFoodFacts: "off-"
        }
    }

    /// Returns the ID for the food this source knows as `code`, such as `usda-173944` for FoodData Central ID 173944.
    func foodID(code: String) -> String {
        idPrefix + code
    }

    /// Returns the code this source knows the food by: the part of `foodID` after `idPrefix`.
    ///
    /// Returns `nil` when `foodID` doesn't start with this source's prefix.
    func code(fromFoodID foodID: String) -> String? {
        guard foodID.hasPrefix(idPrefix) else { return nil }
        return String(foodID.dropFirst(idPrefix.count))
    }
}
