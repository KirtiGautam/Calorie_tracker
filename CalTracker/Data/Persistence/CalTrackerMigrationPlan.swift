import SwiftData

/// The ordered schema versions and the migrations between them.
nonisolated enum CalTrackerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3]
    }

    /// Adds the optional sync fields and the deletion model. Old entries get a sync ID before their first push.
    static var migrateV1toV2: MigrationStage {
        .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)
    }

    /// Adds the custom food model. The log is unchanged.
    static var migrateV2toV3: MigrationStage {
        .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self)
    }
}
