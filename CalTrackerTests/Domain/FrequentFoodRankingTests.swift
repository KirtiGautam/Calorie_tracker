import Foundation
import Testing
@testable import CalTracker

struct FrequentFoodRankingTests {
    private let calendar: Calendar
    private let banana = FoodItem.fixture(id: "usda-1", name: "Banana")
    private let oats = FoodItem.fixture(id: "usda-2", name: "Oats")
    private let coffee = FoodItem.fixture(id: "off-3", name: "Coffee", source: .openFoodFacts)

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        self.calendar = calendar
    }

    @Test func distinctDaysOutrankRepeatsOnOneDay() throws {
        let records = [
            try record(coffee, at: "2026-10-23T08:00:00Z"),
            try record(coffee, at: "2026-10-23T11:00:00Z"),
            try record(coffee, at: "2026-10-23T15:00:00Z"),
            try record(oats, at: "2026-10-21T08:00:00Z"),
            try record(oats, at: "2026-10-22T08:00:00Z"),
        ]

        let ranked = FrequentFoodRanking.rank(records, calendar: calendar)

        #expect(ranked.map(\.id) == [oats.id, coffee.id])
    }

    @Test func tiesGoToTheMostRecentlyLoggedFood() throws {
        let records = [
            try record(banana, at: "2026-10-22T08:00:00Z"),
            try record(oats, at: "2026-10-23T08:00:00Z"),
        ]

        let ranked = FrequentFoodRanking.rank(records, calendar: calendar)

        #expect(ranked.map(\.id) == [oats.id, banana.id])
    }

    @Test func fullTiesAreOrderedByIDWhateverTheInputOrder() throws {
        let records = [
            try record(oats, at: "2026-10-23T08:00:00Z"),
            try record(banana, at: "2026-10-23T08:00:00Z"),
        ]

        let ranked = FrequentFoodRanking.rank(records, calendar: calendar)
        let reversed = FrequentFoodRanking.rank(records.reversed(), calendar: calendar)

        #expect(ranked.map(\.id) == [banana.id, oats.id])
        #expect(reversed.map(\.id) == ranked.map(\.id))
    }

    @Test func eachFoodCarriesItsLatestSnapshotAndAmount() throws {
        let renamed = FoodItem.fixture(id: banana.id, name: "Bananas, raw", brand: "Chiquita")
        let records = [
            try record(renamed, grams: 120, at: "2026-10-23T08:00:00Z"),
            try record(banana, grams: 90, at: "2026-10-20T08:00:00Z"),
        ]

        let food = try #require(FrequentFoodRanking.rank(records, calendar: calendar).first)

        #expect(food.food == renamed)
        #expect(food.grams == 120)
    }

    @Test(arguments: [0.0, -5, .infinity, .nan])
    func recordsWithAnInvalidAmountAreIgnored(grams: Double) throws {
        let records = [
            try record(banana, grams: grams, at: "2026-10-23T08:00:00Z"),
            try record(banana, grams: 110, at: "2026-10-22T08:00:00Z"),
        ]

        let food = try #require(FrequentFoodRanking.rank(records, calendar: calendar).first)

        #expect(food.grams == 110)
    }

    @Test func recordsWithoutAFoodIDAreIgnored() throws {
        let records = [
            try record(.fixture(id: "", name: "Unknown"), at: "2026-10-23T08:00:00Z"),
            try record(banana, at: "2026-10-22T08:00:00Z"),
        ]

        let ranked = FrequentFoodRanking.rank(records, calendar: calendar)

        #expect(ranked.map(\.id) == [banana.id])
    }

    @Test func returnsAtMostTheLimit() throws {
        let records = try (1...12).map { index in
            try record(.fixture(id: "usda-\(index)"), at: "2026-10-23T08:00:00Z")
        }

        #expect(FrequentFoodRanking.rank(records, calendar: calendar).count == FrequentFoodRanking.limit)
        #expect(FrequentFoodRanking.rank(records, calendar: calendar, limit: 3).count == 3)
    }

    @Test func noRecordsRankNoFoods() {
        #expect(FrequentFoodRanking.rank([], calendar: calendar).isEmpty)
    }

    @Test func windowStartsAtTheStartOfTheDayThirtyDaysBack() throws {
        let now = try Date("2026-10-23T18:45:00Z", strategy: .iso8601)

        let start = FrequentFoodRanking.windowStart(endingAt: now, calendar: calendar)

        #expect(start == (try Date("2026-09-23T00:00:00Z", strategy: .iso8601)))
    }

    private func record(_ food: FoodItem, grams: Double = 100, at timestamp: String) throws -> FoodLogRecord {
        FoodLogRecord(food: food, grams: grams, loggedAt: try Date(timestamp, strategy: .iso8601))
    }
}
