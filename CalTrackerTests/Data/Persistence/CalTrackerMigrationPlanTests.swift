import Foundation
import SwiftData
import Testing
@testable import CalTracker

@Suite(.tags(.persistence))
struct CalTrackerMigrationPlanTests {
    /// A fresh directory for this test's store files, removed when the test ends.
    private let directory = URL.temporaryDirectory.appending(path: "MigrationTest-\(UUID().uuidString)")

    init() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    @Test func version1StoreMigratesToVersion2() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "CalTracker.store")
        let loggedAt = try Date("2026-10-23T12:00:00Z", strategy: .iso8601)

        do {
            let schema = Schema(versionedSchema: SchemaV1.self)
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            container.mainContext.insert(SchemaV1.FoodLogEntry(food: .fixture(), grams: 150, loggedAt: loggedAt))
            try container.mainContext.save()
        }

        let container = try openCurrentSchema(at: url)

        let entries = try container.mainContext.fetch(FetchDescriptor<FoodLogEntry>())
        let entry = try #require(entries.first)
        #expect(entries.count == 1)
        #expect(entry.grams == 150)
        #expect(entry.loggedAt == loggedAt)
        #expect(entry.syncID == nil)
        #expect(entry.syncedDay == nil)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<FoodLogDeletion>()) == 0)
    }

    /// Opens a store written by the version 1 app, so a change to a type the old schema stores can't go unnoticed.
    @Test func storeWrittenByVersion1MigratesToTheCurrentSchema() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let container = try openCurrentSchema(at: copyFixture(named: "caltracker_v1"))

        let entries = try container.mainContext.fetch(FetchDescriptor<FoodLogEntry>(sortBy: [SortDescriptor(\.loggedAt)]))
        try #require(entries.count == 2)
        let banana = entries[0]
        #expect(banana.foodID == "usda-173944")
        #expect(banana.name == "Bananas, raw")
        #expect(banana.brand == nil)
        #expect(banana.source == .usda)
        #expect(banana.grams == 150)
        #expect(banana.loggedAt == (try Date("2026-10-20T08:15:00Z", strategy: .iso8601)))
        #expect(banana.per100g.energy == 89)
        #expect(banana.per100g.potassium == 358)
        #expect(banana.per100g.folate == 20)
        #expect(banana.syncID == nil)
        #expect(banana.syncedDay == nil)

        let nutella = entries[1]
        #expect(nutella.foodID == "off-3017620422003")
        #expect(nutella.brand == "Ferrero")
        #expect(nutella.source == .openFoodFacts)
        #expect(nutella.per100g.sodium == 42.8)
        #expect(nutella.per100g.fiber == nil)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<FoodLogDeletion>()) == 0)
    }

    /// Opens a store written by the current schema version. It fails when a stored type changes without a new
    /// schema version, which would otherwise stop the app from opening existing stores.
    @Test func storeWrittenByVersion2OpensWithTheCurrentSchema() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let container = try openCurrentSchema(at: copyFixture(named: "caltracker_v2"))

        let entries = try container.mainContext.fetch(FetchDescriptor<FoodLogEntry>(sortBy: [SortDescriptor(\.loggedAt)]))
        try #require(entries.count == 2)
        #expect(entries[0].syncID == UUID(uuidString: "6F1D2C3B-4A59-4E7F-8A1B-2C3D4E5F6A7B"))
        #expect(entries[0].syncedDay == "2026-10-28")
        #expect(entries[0].per100g.vitaminC == 8.7)
        #expect(entries[1].syncID == nil)
        #expect(entries[1].syncedDay == nil)

        let deletions = try container.mainContext.fetch(FetchDescriptor<FoodLogDeletion>())
        #expect(deletions.map(\.syncID) == [UUID(uuidString: "0A1B2C3D-4E5F-4061-8273-94A5B6C7D8E9")])
        #expect(deletions.map(\.day) == ["2026-10-27"])
    }

    /// Copies a bundled store into this test's directory, so opening it never touches the bundle.
    private func copyFixture(named name: String) throws -> URL {
        let destination = directory.appending(path: "\(name).store")
        try FileManager.default.copyItem(at: FixtureLoader.url(named: name, withExtension: "store"), to: destination)
        return destination
    }

    /// Opens the store at `url` the way the app does, with the current schema and the migration plan.
    private func openCurrentSchema(at url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV2.self)
        return try ModelContainer(
            for: schema,
            migrationPlan: CalTrackerMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, url: url)
        )
    }
}
