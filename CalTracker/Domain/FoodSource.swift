import Foundation

/// The database a food came from.
nonisolated enum FoodSource: String, Codable, Hashable, Sendable {
    case usda
    case openFoodFacts

    /// The localized source name shown in badges.
    var title: LocalizedStringResource {
        switch self {
        case .usda: .sourceUSDA
        case .openFoodFacts: .sourceOpenFoodFacts
        }
    }
}
