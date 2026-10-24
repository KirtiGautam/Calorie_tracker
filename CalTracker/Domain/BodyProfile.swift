/// The body measurements the target calculator needs, in metric units.
nonisolated struct BodyProfile: Codable, Hashable, Sendable {
    /// The sex the energy formula uses.
    var sex: BiologicalSex

    /// The age in whole years.
    var age: Int

    /// The height in centimetres.
    var heightCentimetres: Double

    /// The body weight in kilograms.
    var weightKilograms: Double

    /// How active the person usually is.
    var activity: ActivityLevel
}
