import SwiftData

/// Creates the SwiftData container for the app, previews and tests.
enum AppModelContainer {
    /// A shared in-memory container for SwiftUI previews.
    static let preview = make(inMemory: true)

    /// Creates a container using the versioned schema.
    ///
    /// In-memory containers skip the migration plan, which can make `save()` fail
    /// nondeterministically when there's no store on disk to migrate.
    static func make(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: inMemory ? nil : CalTrackerMigrationPlan.self,
                configurations: configuration
            )
        } catch {
            fatalError("CalTracker couldn't open its database: \(error)")
        }
    }
}
