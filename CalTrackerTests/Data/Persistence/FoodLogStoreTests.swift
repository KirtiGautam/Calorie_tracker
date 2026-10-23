import Foundation
import SwiftData
import Testing
@testable import CalTracker

@Suite(.tags(.persistence))
struct FoodLogStoreTests {
    private let container = AppModelContainer.make(inMemory: true)
    private let calendar: Calendar
    private let food = FoodItem.fixture(per100g: NutrientProfile(energy: 200, protein: 10))

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        self.calendar = calendar
    }

    private var store: FoodLogStore {
        FoodLogStore(modelContext: container.mainContext)
    }

    @Test func loggedEntryCanBeFetched() throws {
        let noon = try Date("2026-10-23T12:00:00Z", strategy: .iso8601)

        try store.log(food, grams: 150, loggedAt: noon)

        let entries = try fetchEntries(onSameDayAs: noon)
        let entry = try #require(entries.first)
        #expect(entries.count == 1)
        #expect(entry.foodID == food.id)
        #expect(entry.grams == 150)
        #expect(entry.per100g == food.per100g)
        #expect(entry.nutrients.energy == 300)
    }

    @Test func deletedEntryIsGone() throws {
        let noon = try Date("2026-10-23T12:00:00Z", strategy: .iso8601)
        try store.log(food, grams: 100, loggedAt: noon)
        let entry = try #require(try fetchEntries(onSameDayAs: noon).first)

        try store.delete(entry)

        #expect(try fetchEntries(onSameDayAs: noon).isEmpty)
    }

    @Test func todayPredicateExcludesYesterdayAndTomorrow() throws {
        let todayStart = try Date("2026-10-23T00:00:00Z", strategy: .iso8601)
        let lateYesterday = try Date("2026-10-22T23:59:59Z", strategy: .iso8601)
        let lateToday = try Date("2026-10-23T23:59:59Z", strategy: .iso8601)
        let tomorrowStart = try Date("2026-10-24T00:00:00Z", strategy: .iso8601)
        for date in [lateYesterday, todayStart, lateToday, tomorrowStart] {
            try store.log(food, grams: 100, loggedAt: date)
        }

        let entries = try fetchEntries(onSameDayAs: try Date("2026-10-23T09:30:00Z", strategy: .iso8601))

        #expect(Set(entries.map(\.loggedAt)) == [todayStart, lateToday])
    }

    @Test(arguments: [0.0, -10, Double.nan])
    func refusesInvalidAmounts(grams: Double) throws {
        let noon = try Date("2026-10-23T12:00:00Z", strategy: .iso8601)

        #expect(throws: LogFoodError.invalidAmount) {
            try store.log(food, grams: grams, loggedAt: noon)
        }
        #expect(try fetchEntries(onSameDayAs: noon).isEmpty)
    }

    private func fetchEntries(onSameDayAs date: Date) throws -> [FoodLogEntry] {
        let descriptor = FetchDescriptor<FoodLogEntry>(
            predicate: FoodLogEntry.loggedOnSameDay(as: date, calendar: calendar),
            sortBy: [SortDescriptor(\.loggedAt)]
        )
        return try container.mainContext.fetch(descriptor)
    }
}
