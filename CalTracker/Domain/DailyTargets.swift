/// The person's daily targets for the headline macros, each in its `Nutrient.unit`.
///
/// `nil` means there's no target for that nutrient.
nonisolated struct DailyTargets: Codable, Hashable, Sendable {
    var energy: Double?
    var protein: Double?
    var carbohydrates: Double?
    var fat: Double?

    /// Whether no nutrient has a target.
    var isEmpty: Bool {
        Nutrient.macros.allSatisfy { self[$0] == nil }
    }

    /// Accesses the target for a nutrient. Micronutrients never have one.
    subscript(nutrient: Nutrient) -> Double? {
        get {
            switch nutrient {
            case .energy: energy
            case .protein: protein
            case .carbohydrates: carbohydrates
            case .fat: fat
            default: nil
            }
        }
        set {
            switch nutrient {
            case .energy: energy = newValue
            case .protein: protein = newValue
            case .carbohydrates: carbohydrates = newValue
            case .fat: fat = newValue
            default: break
            }
        }
    }

    /// Returns how today's total of `nutrient` compares with its target, or `nil` when there's no target.
    ///
    /// An unknown total counts as 0, because nothing that reported it has been eaten.
    func progress(for nutrient: Nutrient, in totals: DailyTotals) -> TargetProgress? {
        guard let target = self[nutrient], target > 0 else { return nil }
        return TargetProgress(nutrient: nutrient, total: totals.profile[nutrient] ?? 0, target: target)
    }
}
