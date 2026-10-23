import Foundation

/// How active the person is, which scales resting energy to a daily total.
nonisolated enum ActivityLevel: String, CaseIterable, Identifiable, Codable, Sendable {
    case sedentary
    case light
    case moderate
    case veryActive
    case extraActive

    /// The stable identity of the option.
    var id: Self { self }

    /// The localized name shown in the picker.
    var title: LocalizedStringResource {
        switch self {
        case .sedentary: .activitySedentary
        case .light: .activityLight
        case .moderate: .activityModerate
        case .veryActive: .activityVeryActive
        case .extraActive: .activityExtraActive
        }
    }

    /// The factor that turns resting energy into total daily energy.
    var multiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .veryActive: 1.725
        case .extraActive: 1.9
        }
    }
}
