import SwiftData

/// The second version of CalTracker's persistent schema, which adds what cloud sync needs.
///
/// `FoodLogEntry` gains a sync ID and the server day it was pushed to, and `FoodLogDeletion`
/// remembers deleted entries until the server has been told.
///
/// It stores the app's live `NutrientProfile`, so changing that type needs a version 3. When you add one, give this
/// version a frozen copy of `NutrientProfile` the way `SchemaV1.NutrientProfile` does, and add a version 2 store
/// fixture test like the ones in `CalTrackerMigrationPlanTests`.
nonisolated enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(2, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [FoodLogEntry.self, FoodLogDeletion.self]
    }
}
