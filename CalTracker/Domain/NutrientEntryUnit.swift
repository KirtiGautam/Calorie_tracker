import Foundation

/// A unit the person can type a nutrient amount in. Amounts are converted to the nutrient's `Nutrient.unit` before
/// they're stored.
nonisolated enum NutrientEntryUnit: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case kilocalories
    case kilojoules
    case grams
    case milligrams
    case micrograms
    case internationalUnits

    /// Micrograms of vitamin D (cholecalciferol) per International Unit.
    static let vitaminDMicrogramsPerIU = 0.025

    /// The entry unit that matches the stored unit `unit`, so its amounts need no conversion.
    init(_ unit: NutrientUnit) {
        self = switch unit {
        case .kilocalories: .kilocalories
        case .grams: .grams
        case .milligrams: .milligrams
        case .micrograms: .micrograms
        }
    }

    /// The stable identity of the unit.
    var id: Self { self }

    /// The unit's localized abbreviation, such as "kJ" or "IU".
    var symbol: String {
        switch self {
        case .kilojoules: NutrientUnit.abbreviation(of: UnitEnergy.kilojoules)
        case .internationalUnits: String(localized: .unitInternationalUnits)
        default: storedUnit?.symbol ?? ""
        }
    }

    /// Converts `amount`, typed in this unit, into `nutrient`'s `Nutrient.unit`.
    ///
    /// - Returns: The converted amount, or `nil` when this unit can't measure the nutrient, such as kJ for protein or
    ///   IU for anything but vitamin D. Vitamin A in IU depends on the source compound, so it has no fixed conversion.
    func amount(_ amount: Double, of nutrient: Nutrient) -> Double? {
        if nutrient.unit == .kilocalories {
            return switch self {
            case .kilocalories: amount
            case .kilojoules: amount / NutrientUnit.kilojoulesPerKilocalorie
            default: nil
            }
        }

        switch self {
        case .kilocalories, .kilojoules:
            return nil
        case .internationalUnits:
            return nutrient == .vitaminD ? amount * Self.vitaminDMicrogramsPerIU : nil
        case .grams, .milligrams, .micrograms:
            // One combined factor keeps same-unit values exact (12.5 µg stays 12.5, not 12.499999999999998).
            return storedUnit.map { amount * (nutrient.unit.perGram / $0.perGram) }
        }
    }

    /// The stored unit with the same meaning, or `nil` for kJ and IU, which aren't stored.
    private var storedUnit: NutrientUnit? {
        switch self {
        case .kilocalories: .kilocalories
        case .grams: .grams
        case .milligrams: .milligrams
        case .micrograms: .micrograms
        case .kilojoules, .internationalUnits: nil
        }
    }
}
