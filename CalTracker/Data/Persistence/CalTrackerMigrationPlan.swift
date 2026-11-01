import SwiftData

/// The ordered schema versions and the migrations between them.
nonisolated enum CalTrackerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    /// Adds the optional sync fields and the deletion model. Old entries get a sync ID before their first push.
    static var migrateV1toV2: MigrationStage {
        .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)
    }
}
