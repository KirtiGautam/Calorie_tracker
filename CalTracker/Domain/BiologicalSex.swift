import Foundation

/// The sex the energy formula uses, or neither.
nonisolated enum BiologicalSex: String, CaseIterable, Identifiable, Codable, Sendable {
    case female
    case male

    /// Uses the midpoint of the female and male formulas.
    case unspecified

    /// The stable identity of the option.
    var id: Self { self }

    /// The localized name shown in the picker.
    var title: LocalizedStringResource {
        switch self {
        case .female: .sexFemale
        case .male: .sexMale
        case .unspecified: .sexUnspecified
        }
    }

    /// The constant Mifflin-St Jeor adds to the resting energy estimate, in kcal.
    var mifflinOffset: Double {
        switch self {
        case .female: -161
        case .male: 5
        case .unspecified: -78
        }
    }
}
