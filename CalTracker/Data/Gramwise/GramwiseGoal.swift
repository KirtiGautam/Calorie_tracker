import Foundation

/// The daily targets and weight goal as the backend stores them.
nonisolated struct GramwiseGoal: Codable, Hashable, Sendable {
    /// Whether the person is cutting, maintaining or bulking.
    let goal: WeightGoal

    /// The macro targets. A `nil` field has no target.
    let targets: DailyTargets

    /// When the person saved the goal. The newest save of a day wins.
    let updatedAt: Date

    /// The day the goal applies from, such as `2026-11-01`: the day it was saved on, on the device that saved it.
    ///
    /// The server keeps one goal per day, so a goal saved on a later day doesn't change earlier days' goals, and it
    /// refuses a goal dated before its current one.
    let effectiveFrom: String

    /// Creates a goal from its parts.
    init(goal: WeightGoal, targets: DailyTargets, updatedAt: Date, effectiveFrom: String) {
        self.goal = goal
        self.targets = targets
        self.updatedAt = updatedAt
        self.effectiveFrom = effectiveFrom
    }

    private enum CodingKeys: String, CodingKey {
        case goal
        case energyKcal = "energy_kcal"
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case updatedAt = "updated_at"
        case effectiveFrom = "effective_from"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        goal = try container.decode(WeightGoal.self, forKey: .goal)
        targets = DailyTargets(
            energy: try container.decodeIfPresent(Double.self, forKey: .energyKcal),
            protein: try container.decodeIfPresent(Double.self, forKey: .proteinG),
            carbohydrates: try container.decodeIfPresent(Double.self, forKey: .carbsG),
            fat: try container.decodeIfPresent(Double.self, forKey: .fatG)
        )
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        effectiveFrom = try container.decode(String.self, forKey: .effectiveFrom)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(goal, forKey: .goal)
        // Explicit nulls, so clearing a target on one device clears it on the others.
        try container.encode(targets.energy, forKey: .energyKcal)
        try container.encode(targets.protein, forKey: .proteinG)
        try container.encode(targets.carbohydrates, forKey: .carbsG)
        try container.encode(targets.fat, forKey: .fatG)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(effectiveFrom, forKey: .effectiveFrom)
    }
}
