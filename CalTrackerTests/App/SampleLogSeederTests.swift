#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import CalTracker

@Suite(.tags(.persistence))
struct SampleLogSeederTests {
    private let container = AppModelContainer.make(inMemory: true)
    private let isolatedDefaults = IsolatedDefaults()
    private let calendar: Calendar
    private let now: Date

    init() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        self.calendar = calendar
        now = try Date("2026-10-24T09:30:00Z", strategy: .iso8601)
    }

    @Test func nothingIsSeededWithoutTheLaunchArgument() throws {
        seedIfRequested(arguments: [])

        #expect(try allEntries().isEmpty)
    }

    @Test func seedsOnlyThePastDaysLeavingGaps() throws {
        try SampleLogSeeder.seed(into: container.mainContext, now: now, calendar: calendar)

        let today = calendar.startOfDay(for: now)
        let seededDaysAgo = Set(try allEntries().compactMap { entry in
            calendar.dateComponents([.day], from: calendar.startOfDay(for: entry.loggedAt), to: today).day
        })
        #expect(seededDaysAgo == Set(SampleLogSeeder.daysAgo))
    }

    @Test func seededEntriesAreSyncable() throws {
        try SampleLogSeeder.seed(into: container.mainContext, now: now, calendar: calendar)

        let entries = try allEntries()
        #expect(entries.isEmpty == false)
        #expect(entries.allSatisfy(SyncEngine.isSyncable))
        #expect(Set(entries.compactMap(\.syncID)).count == entries.count)
    }

    @Test func seedsOnlyOnce() throws {
        seedIfRequested(arguments: [SampleLogSeeder.launchArgument])
        let countAfterFirstSeed = try allEntries().count
        seedIfRequested(arguments: [SampleLogSeeder.launchArgument])

        #expect(countAfterFirstSeed > 0)
        #expect(try allEntries().count == countAfterFirstSeed)
    }

    @Test func skipsDaysWithRealEntries() throws {
        let realFood = FoodItem.fixture(id: "usda-1")
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: now))
        try FoodLogStore(modelContext: container.mainContext).log(realFood, grams: 100, loggedAt: yesterday)

        try SampleLogSeeder.seed(into: container.mainContext, now: now, calendar: calendar)

        let yesterdays = try container.mainContext.fetch(FetchDescriptor(
            predicate: FoodLogEntry.loggedOnSameDay(as: yesterday, calendar: calendar)
        ))
        #expect(yesterdays.map(\.foodID) == [realFood.id])
    }

    @Test func removesLegacySampleEntries() throws {
        let legacyFood = FoodItem.fixture(id: SampleLogSeeder.legacyIDPrefix + "oats")
        let longAgo = try #require(calendar.date(byAdding: .day, value: -30, to: now))
        try FoodLogStore(modelContext: container.mainContext).log(legacyFood, grams: 50, loggedAt: longAgo)

        try SampleLogSeeder.seed(into: container.mainContext, now: now, calendar: calendar)

        #expect(try allEntries().contains { $0.foodID.hasPrefix(SampleLogSeeder.legacyIDPrefix) } == false)
    }

    private func seedIfRequested(arguments: [String]) {
        SampleLogSeeder.seedIfRequested(
            into: container.mainContext,
            arguments: arguments,
            defaults: isolatedDefaults.defaults,
            now: now,
            calendar: calendar
        )
    }

    private func allEntries() throws -> [FoodLogEntry] {
        try container.mainContext.fetch(FetchDescriptor<FoodLogEntry>())
    }
}
#endif
