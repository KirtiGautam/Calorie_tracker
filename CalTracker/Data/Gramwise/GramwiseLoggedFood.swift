import Foundation

/// One food in a server day. The macros are for the amount eaten, and `nil` means unknown.
nonisolated struct GramwiseLoggedFood: Codable, Hashable, Sendable {
    /// The entry's `FoodLogEntry.syncID`.
    let entryID: UUID

    /// The source-prefixed food ID, such as `usda-173944`, looked up again on restore.
    let foodID: String

    /// The name it was logged under, used when the lookup fails.
    let name: String

    /// The amount eaten, in grams.
    let grams: Double

    /// When it was logged.
    let loggedAt: Date

    /// Energy in the amount eaten, in kcal.
    let energyKcal: Double?

    /// Protein in the amount eaten, in grams.
    let proteinG: Double?

    /// Carbohydrates in the amount eaten, in grams.
    let carbsG: Double?

    /// Fat in the amount eaten, in grams.
    let fatG: Double?

    private enum CodingKeys: String, CodingKey {
        case entryID = "entry_id"
        case foodID = "food_id"
        case name
        case grams
        case loggedAt = "logged_at"
        case energyKcal = "energy_kcal"
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
    }
}
