/// Whether a nutrient is a headline macro or a supporting micronutrient.
nonisolated enum NutrientGroup: String, Codable, Sendable {
    case macro
    case micro
}
