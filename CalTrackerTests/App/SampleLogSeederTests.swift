#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import CalTracker

@Suite(.tags(.persistence))
struct SampleLogSeederTests {
    private let container = AppModelContainer.make(inMemory: true)
    private let calendar: Calendar
    private let now: Date

    init() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        self.calendar = calendar
        now = try Date("2026-10-24T09:30:00Z", strategy: .iso8601)
    }

    @Test func nothingIsSeededWithoutTheLaunchArgument() throws {
        SampleLogSeeder.seedIfRequested(into: container.mainContext, arguments: [], now: now, calendar: calendar)

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

    @Test func seedingAgainReplacesSampleEntriesAndKeepsRealOnes() throws {
        let realFood = FoodItem.fixture(id: "usda-1")
        try FoodLogStore(modelContext: container.mainContext).log(realFood, grams: 100, loggedAt: now)

        try SampleLogSeeder.seed(into: container.mainContext, now: now, calendar: calendar)
        let countAfterFirstSeed = try allEntries().count
        try SampleLogSeeder.seed(into: container.mainContext, now: now, calendar: calendar)

        let entries = try allEntries()
        #expect(entries.count == countAfterFirstSeed)
        #expect(entries.count { $0.foodID == realFood.id } == 1)
    }

    private func allEntries() throws -> [FoodLogEntry] {
        try container.mainContext.fetch(FetchDescriptor<FoodLogEntry>())
    }
}
#endif
