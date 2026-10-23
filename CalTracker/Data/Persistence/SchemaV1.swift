import SwiftData

/// The first version of CalTracker's persistent schema.
nonisolated enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [FoodLogEntry.self]
    }
}
