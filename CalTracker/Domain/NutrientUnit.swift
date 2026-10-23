import Foundation

/// The unit a nutrient amount is stored and displayed in.
nonisolated enum NutrientUnit: String, Codable, Sendable {
    case kilocalories
    case grams
    case milligrams
    case micrograms

    /// How many of this unit make up one gram, used to convert gram-based source data.
    ///
    /// - Note: Energy has no gram equivalent, so kilocalories report `1`.
    var perGram: Double {
        switch self {
        case .kilocalories, .grams: 1
        case .milligrams: 1_000
        case .micrograms: 1_000_000
        }
    }

    /// The unit's localized abbreviation, such as "g" or "kcal", exactly as `formatted(_:)` writes it.
    var symbol: String {
        switch self {
        case .kilocalories: Self.abbreviation(of: UnitEnergy.kilocalories)
        case .grams: Self.abbreviation(of: UnitMass.grams)
        case .milligrams: Self.abbreviation(of: UnitMass.milligrams)
        case .micrograms: Self.abbreviation(of: UnitMass.micrograms)
        }
    }

    /// Formats a sample measurement and keeps only the unit part, since `Dimension.symbol` isn't localized ("kCal").
    private static func abbreviation<UnitType: Dimension>(of unit: UnitType) -> String {
        let formatted = Measurement(value: 1, unit: unit)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided).attributed)
        return formatted.runs[\.measurement]
            .filter { component, _ in component == .unit }
            .map { _, range in String(formatted[range].characters) }
            .joined()
    }

    /// Formats an amount in this unit for display, such as "12.5 mg" or "89 kcal".
    ///
    /// - Parameters:
    ///   - value: The amount, already expressed in this unit.
    ///   - spelledOut: Whether to spell the unit out ("grams"), for spoken accessibility labels.
    /// - Returns: A localized string with at most one fraction digit.
    func formatted(_ value: Double, spelledOut: Bool = false) -> String {
        let number = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...1))
        return switch self {
        case .kilocalories:
            Measurement(value: value, unit: UnitEnergy.kilocalories)
                .formatted(.measurement(width: spelledOut ? .wide : .abbreviated, usage: .asProvided, numberFormatStyle: number))
        case .grams:
            Measurement(value: value, unit: UnitMass.grams)
                .formatted(.measurement(width: spelledOut ? .wide : .abbreviated, usage: .asProvided, numberFormatStyle: number))
        case .milligrams:
            Measurement(value: value, unit: UnitMass.milligrams)
                .formatted(.measurement(width: spelledOut ? .wide : .abbreviated, usage: .asProvided, numberFormatStyle: number))
        case .micrograms:
            Measurement(value: value, unit: UnitMass.micrograms)
                .formatted(.measurement(width: spelledOut ? .wide : .abbreviated, usage: .asProvided, numberFormatStyle: number))
        }
    }
}
