import Foundation

/// Whether the person wants to lose, keep or gain weight.
nonisolated enum WeightGoal: String, CaseIterable, Identifiable, Codable, Sendable {
    case cut
    case maintain
    case bulk

    /// The stable identity of the option.
    var id: Self { self }

    /// The localized name shown in the picker.
    var title: LocalizedStringResource {
        switch self {
        case .cut: .goalCut
        case .maintain: .goalMaintain
        case .bulk: .goalBulk
        }
    }

    /// The one-word name shown in the Today badge.
    var shortTitle: LocalizedStringResource {
        switch self {
        case .cut: .goalShortCut
        case .maintain: .goalShortMaintain
        case .bulk: .goalShortBulk
        }
    }

    /// The SF Symbol shown in the Today badge.
    var systemImage: String {
        switch self {
        case .cut: "arrow.down.right"
        case .maintain: "arrow.right"
        case .bulk: "arrow.up.right"
        }
    }

    /// The factor applied to maintenance energy.
    var energyFactor: Double {
        switch self {
        case .cut: 0.8
        case .maintain: 1
        case .bulk: 1.1
        }
    }

    /// Daily protein per kilogram of body weight, in grams.
    var proteinPerKilogram: Double {
        switch self {
        case .cut: 2
        case .maintain: 1.6
        case .bulk: 1.8
        }
    }
}
