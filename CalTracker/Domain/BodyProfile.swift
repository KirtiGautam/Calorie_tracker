/// The body measurements the target calculator needs, in metric units.
nonisolated struct BodyProfile: Codable, Hashable, Sendable {
    var sex: BiologicalSex
    var age: Int
    var heightCentimetres: Double
    var weightKilograms: Double
    var activity: ActivityLevel
}
