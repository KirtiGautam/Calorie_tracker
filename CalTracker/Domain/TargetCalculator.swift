/// Suggests daily macro targets from body measurements and a goal.
nonisolated enum TargetCalculator {
    /// The lowest energy target a cut suggests, in kcal.
    static let minimumCutEnergy = 1_200.0

    /// The share of energy that comes from fat.
    static let fatEnergyShare = 0.25

    /// Returns suggested targets for `body` working toward `goal`.
    ///
    /// Energy uses the Mifflin-St Jeor resting estimate scaled by activity and goal, rounded to 10 kcal.
    /// Protein is per kilogram of body weight, fat is a quarter of energy, and carbohydrates fill the rest.
    static func targets(for body: BodyProfile, goal: WeightGoal) -> DailyTargets {
        let resting = 10 * body.weightKilograms
            + 6.25 * body.heightCentimetres
            - 5 * Double(body.age)
            + body.sex.mifflinOffset
        var energy = (resting * body.activity.multiplier * goal.energyFactor / 10).rounded() * 10
        if goal == .cut {
            energy = max(energy, minimumCutEnergy)
        }

        let protein = (body.weightKilograms * goal.proteinPerKilogram).rounded()
        let fat = (energy * fatEnergyShare / 9).rounded()
        let carbohydrates = max((energy - 4 * protein - 9 * fat) / 4, 0).rounded()

        return DailyTargets(energy: energy, protein: protein, carbohydrates: carbohydrates, fat: fat)
    }
}
