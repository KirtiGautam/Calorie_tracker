import Foundation

/// Picks the foods the person logs on the most days, for quick add.
///
/// Counting days rather than entries keeps the order steady: three coffees in one morning count once, and one more
/// log moves a food by at most a day. A list that reshuffles under the person's thumb is slower to use than a stable one.
nonisolated enum FrequentFoodRanking {
    /// How many foods quick add offers, which fills about one screen on an iPhone at the default text size.
    static let limit = 8

    /// How many days before today the ranking looks back, so foods the person stopped eating drop off on their own.
    static let lookbackDays = 30

    /// The start of the day `lookbackDays` before the day of `now`, where the window that ranks foods begins.
    static func windowStart(endingAt now: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -lookbackDays, to: today)
            ?? today.addingTimeInterval(-Double(lookbackDays) * 86_400)
    }

    /// Returns at most `limit` foods from `records`, ranked by how many distinct days in `calendar` each was logged on.
    ///
    /// Ties go to the food logged most recently, then to the smaller ID, so the order never depends on input order.
    /// Each food carries its most recent name and nutrients, and its most recent amount. Records without a food ID,
    /// or with an amount that isn't positive and finite, are ignored.
    static func rank(_ records: [FoodLogRecord], calendar: Calendar, limit: Int = limit) -> [FrequentFood] {
        var tallies: [String: Tally] = [:]
        for record in records where record.food.id.isEmpty == false && record.grams > 0 && record.grams.isFinite {
            let day = calendar.startOfDay(for: record.loggedAt)
            tallies[record.food.id, default: Tally(latest: record)].add(record, on: day)
        }

        return tallies.values
            .sorted(by: Tally.ranksBefore)
            .prefix(max(limit, 0))
            .map { FrequentFood(food: $0.latest.food, grams: $0.latest.grams) }
    }

    /// What the ranking knows about one food.
    private struct Tally {
        /// The food's most recent record.
        var latest: FoodLogRecord

        /// The start of every day the food was logged on.
        var days: Set<Date> = []

        /// Counts `record`, logged on the day starting at `day`, keeping it as the latest when it's newer.
        mutating func add(_ record: FoodLogRecord, on day: Date) {
            days.insert(day)
            if record.loggedAt > latest.loggedAt {
                latest = record
            }
        }

        /// Whether `lhs` belongs above `rhs`: more days first, then the more recent log, then the smaller ID.
        static func ranksBefore(_ lhs: Tally, _ rhs: Tally) -> Bool {
            if lhs.days.count != rhs.days.count {
                return lhs.days.count > rhs.days.count
            }
            if lhs.latest.loggedAt != rhs.latest.loggedAt {
                return lhs.latest.loggedAt > rhs.latest.loggedAt
            }
            return lhs.latest.food.id < rhs.latest.food.id
        }
    }
}
