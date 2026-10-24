import Foundation

/// Works out which days the Today screen can step to from the day it shows, skipping days with nothing logged.
nonisolated struct DayNavigation: Hashable, Sendable {
    /// Whether the shown day is today.
    let isToday: Bool

    /// The start of the latest earlier day with entries, or `nil` when nothing was logged before the shown day.
    let previous: Date?

    /// The start of the next later day with entries, today when there's none, or `nil` when the shown day is today.
    let next: Date?

    /// Creates the navigation for `day`.
    ///
    /// - Parameters:
    ///   - day: Any moment in the day being shown.
    ///   - today: Any moment in the current day.
    ///   - previousEntryDate: When the latest entry before `day` was logged, if any.
    ///   - nextEntryDate: When the earliest entry after `day` and before `today` was logged, if any.
    ///   - calendar: The calendar that defines where days start.
    init(day: Date, today: Date, previousEntryDate: Date?, nextEntryDate: Date?, calendar: Calendar) {
        let dayStart = calendar.startOfDay(for: day)
        let todayStart = calendar.startOfDay(for: today)
        isToday = dayStart >= todayStart
        previous = previousEntryDate.map(calendar.startOfDay(for:))
        if isToday {
            next = nil
        } else {
            next = nextEntryDate.map(calendar.startOfDay(for:)) ?? todayStart
        }
    }
}
