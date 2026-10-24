import Foundation
import SwiftData
import Testing
@testable import CalTracker

@Suite(.tags(.persistence))
struct FoodLogEntryTests {
    private let container = AppModelContainer.make(inMemory: true)
    private let calendar: Calendar
    private let food = FoodItem.fixture()

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        self.calendar = calendar
    }

    @Test func beforeDayPredicateStopsAtMidnight() throws {
        let lateYesterday = try Date("2026-10-22T23:59:59Z", strategy: .iso8601)
        let todayStart = try Date("2026-10-23T00:00:00Z", strategy: .iso8601)
        try log(at: [lateYesterday, todayStart])

        let entries = try fetchEntries(FoodLogEntry.loggedBeforeDay(
            of: try Date("2026-10-23T09:30:00Z", strategy: .iso8601),
            calendar: calendar
        ))

        #expect(entries.map(\.loggedAt) == [lateYesterday])
    }

    @Test func betweenDaysPredicateExcludesBothBoundaryDays() throws {
        let lateDay = try Date("2026-10-21T23:59:59Z", strategy: .iso8601)
        let nextDayStart = try Date("2026-10-22T00:00:00Z", strategy: .iso8601)
        let lateBeforeToday = try Date("2026-10-23T23:59:59Z", strategy: .iso8601)
        let todayStart = try Date("2026-10-24T00:00:00Z", strategy: .iso8601)
        try log(at: [lateDay, nextDayStart, lateBeforeToday, todayStart])

        let entries = try fetchEntries(FoodLogEntry.loggedBetweenDay(
            after: try Date("2026-10-21T12:00:00Z", strategy: .iso8601),
            andDay: try Date("2026-10-24T09:30:00Z", strategy: .iso8601),
            calendar: calendar
        ))

        #expect(entries.map(\.loggedAt) == [nextDayStart, lateBeforeToday])
    }

    private func log(at dates: [Date]) throws {
        let store = FoodLogStore(modelContext: container.mainContext)
        for date in dates {
            try store.log(food, grams: 100, loggedAt: date)
        }
    }

    private func fetchEntries(_ predicate: Predicate<FoodLogEntry>) throws -> [FoodLogEntry] {
        let descriptor = FetchDescriptor<FoodLogEntry>(predicate: predicate, sortBy: [SortDescriptor(\.loggedAt)])
        return try container.mainContext.fetch(descriptor)
    }
}
