import SwiftData

/// The second version of CalTracker's persistent schema, which adds what cloud sync needs.
///
/// `FoodLogEntry` gains a sync ID and the server day it was pushed to, and `FoodLogDeletion`
/// remembers deleted entries until the server has been told.
nonisolated enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(2, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [FoodLogEntry.self, FoodLogDeletion.self]
    }
}
