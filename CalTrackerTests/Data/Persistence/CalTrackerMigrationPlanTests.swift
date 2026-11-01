import Foundation
import SwiftData
import Testing
@testable import CalTracker

@Suite(.tags(.persistence))
struct CalTrackerMigrationPlanTests {
    @Test func version1StoreMigratesToVersion2() throws {
        let directory = URL.temporaryDirectory.appending(path: "MigrationTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "CalTracker.store")
        let loggedAt = try Date("2026-10-23T12:00:00Z", strategy: .iso8601)

        do {
            let schema = Schema(versionedSchema: SchemaV1.self)
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            container.mainContext.insert(SchemaV1.FoodLogEntry(food: .fixture(), grams: 150, loggedAt: loggedAt))
            try container.mainContext.save()
        }

        let schema = Schema(versionedSchema: SchemaV2.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: CalTrackerMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, url: url)
        )

        let entries = try container.mainContext.fetch(FetchDescriptor<FoodLogEntry>())
        let entry = try #require(entries.first)
        #expect(entries.count == 1)
        #expect(entry.grams == 150)
        #expect(entry.loggedAt == loggedAt)
        #expect(entry.syncID == nil)
        #expect(entry.syncedDay == nil)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<FoodLogDeletion>()) == 0)
    }
}
