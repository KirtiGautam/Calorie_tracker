import SwiftData

/// The third version of CalTracker's persistent schema, which adds the foods the person enters themselves.
///
/// The log models are version 2's, unchanged. Every model here stores the app's live `NutrientProfile`, so changing
/// that type needs a version 4. When you add one, give versions 2 and 3 frozen copies of their models and of
/// `NutrientProfile`, the way `SchemaV1` has them, and add a version 3 store fixture test like the ones in
/// `CalTrackerMigrationPlanTests`.
nonisolated enum SchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(3, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [SchemaV2.FoodLogEntry.self, SchemaV2.FoodLogDeletion.self, CustomFood.self]
    }
}
