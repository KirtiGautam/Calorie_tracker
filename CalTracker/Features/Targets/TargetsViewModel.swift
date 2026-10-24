import Foundation
import Observation

/// Holds draft body measurements, goal and targets, and suggests targets from the measurements.
@Observable
final class TargetsViewModel {
    /// The ages the calculator accepts.
    static let ageRange = 15...100

    /// The heights the calculator accepts, in centimetres.
    static let heightRange = 100.0...250

    /// The weights the calculator accepts, in kilograms.
    static let weightRange = 30.0...300

    /// The goal being edited.
    var goal: WeightGoal

    /// The sex being edited.
    var sex: BiologicalSex

    /// The age being edited, or `nil` while the field is empty.
    var age: Int?

    /// The height being edited, in centimetres, or `nil` while the field is empty.
    var heightCentimetres: Double?

    /// The weight being edited, in kilograms, or `nil` while the field is empty.
    var weightKilograms: Double?

    /// The activity level being edited.
    var activity: ActivityLevel

    /// The targets being edited.
    var targets: DailyTargets

    @ObservationIgnored private let store: TargetsStore

    /// Creates a view model prefilled from what `store` last saved.
    init(store: TargetsStore) {
        self.store = store
        goal = store.goal ?? .maintain
        sex = store.bodyProfile?.sex ?? .unspecified
        age = store.bodyProfile?.age
        heightCentimetres = store.bodyProfile?.heightCentimetres
        weightKilograms = store.bodyProfile?.weightKilograms
        activity = store.bodyProfile?.activity ?? .moderate
        targets = store.targets
    }

    /// The draft measurements, or `nil` while any is missing or out of range.
    var bodyProfile: BodyProfile? {
        guard let age, Self.ageRange.contains(age),
              let heightCentimetres, Self.heightRange.contains(heightCentimetres),
              let weightKilograms, Self.weightRange.contains(weightKilograms)
        else { return nil }
        return BodyProfile(
            sex: sex,
            age: age,
            heightCentimetres: heightCentimetres,
            weightKilograms: weightKilograms,
            activity: activity
        )
    }

    /// Whether the measurements are complete enough to suggest targets.
    var canCalculate: Bool {
        bodyProfile != nil
    }

    /// Whether every target is blank or a positive, finite amount.
    var isValid: Bool {
        Nutrient.macros.allSatisfy { nutrient in
            guard let value = targets[nutrient] else { return true }
            return value > 0 && value.isFinite
        }
    }

    /// Replaces the draft targets with ones suggested from the measurements and goal.
    func calculate() {
        guard let bodyProfile else { return }
        targets = TargetCalculator.targets(for: bodyProfile, goal: goal)
    }

    /// Saves the goal and targets, and the measurements when they're complete.
    ///
    /// - Throws: `LogFoodError.invalidAmount` when `isValid` is false, or the store's encoding error.
    func save() throws {
        guard isValid else { throw LogFoodError.invalidAmount }
        try store.save(targets: targets, bodyProfile: bodyProfile, goal: goal)
    }
}
