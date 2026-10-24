import Foundation
import Testing
@testable import CalTracker

struct DayNavigationTests {
    private let calendar: Calendar

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        self.calendar = calendar
    }

    @Test func todayCannotGoForward() throws {
        let today = try Date("2026-10-24T09:30:00Z", strategy: .iso8601)

        let navigation = DayNavigation(
            day: today,
            today: today,
            previousEntryDate: nil,
            nextEntryDate: nil,
            calendar: calendar
        )

        #expect(navigation.isToday)
        #expect(navigation.next == nil)
    }

    @Test func pastDayWithNothingLaterGoesForwardToToday() throws {
        let today = try Date("2026-10-24T09:30:00Z", strategy: .iso8601)
        let day = try Date("2026-10-20T00:00:00Z", strategy: .iso8601)

        let navigation = DayNavigation(day: day, today: today, previousEntryDate: nil, nextEntryDate: nil, calendar: calendar)

        #expect(navigation.isToday == false)
        #expect(navigation.next == (try Date("2026-10-24T00:00:00Z", strategy: .iso8601)))
    }

    @Test func emptyDaysAreSkippedInBothDirections() throws {
        let today = try Date("2026-10-24T09:30:00Z", strategy: .iso8601)
        let day = try Date("2026-10-20T00:00:00Z", strategy: .iso8601)

        let navigation = DayNavigation(
            day: day,
            today: today,
            previousEntryDate: try Date("2026-10-17T15:45:00Z", strategy: .iso8601),
            nextEntryDate: try Date("2026-10-22T08:10:00Z", strategy: .iso8601),
            calendar: calendar
        )

        #expect(navigation.previous == (try Date("2026-10-17T00:00:00Z", strategy: .iso8601)))
        #expect(navigation.next == (try Date("2026-10-22T00:00:00Z", strategy: .iso8601)))
    }

    @Test func nothingEarlierMeansNoPrevious() throws {
        let today = try Date("2026-10-24T09:30:00Z", strategy: .iso8601)

        let navigation = DayNavigation(day: today, today: today, previousEntryDate: nil, nextEntryDate: nil, calendar: calendar)

        #expect(navigation.previous == nil)
    }
}
