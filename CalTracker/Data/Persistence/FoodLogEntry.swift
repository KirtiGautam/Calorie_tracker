import Foundation
import SwiftData

/// The current version of a logged food.
typealias FoodLogEntry = SchemaV2.FoodLogEntry

extension SchemaV2 {
    /// One food the person logged, with the amount they ate.
    @Model
    final class FoodLogEntry {
        #Index<FoodLogEntry>([\.loggedAt])

        /// The `FoodItem.id` the entry was logged from.
        var foodID: String = ""

        /// The food's name at the time it was logged.
        var name: String = ""

        /// The food's brand at the time it was logged.
        var brand: String?

        /// The database the food came from.
        var source: FoodSource = FoodSource.usda

        /// The amount eaten, in grams.
        var grams: Double = 0

        /// The food's nutrients per 100 g, so the amount can be edited later.
        var per100g: NutrientProfile = NutrientProfile()

        /// When the food was logged.
        var loggedAt: Date = Date.now

        /// The ID the server knows the entry by.
        ///
        /// New entries get one in `init`. Entries migrated from version 1 have none until their first push.
        /// It's optional because a migration default would give every old entry the same ID.
        var syncID: UUID?

        /// The server day (`yyyy-MM-dd`) the entry was pushed to, or `nil` when it hasn't been pushed yet.
        var syncedDay: String?

        /// Creates an entry for `grams` of `food` logged at `loggedAt`.
        ///
        /// - Parameters:
        ///   - syncID: The server's ID for the entry. A new one by default.
        ///   - syncedDay: The server day the entry came from, when it's restored from the server.
        init(food: FoodItem, grams: Double, loggedAt: Date, syncID: UUID = UUID(), syncedDay: String? = nil) {
            foodID = food.id
            name = food.name
            brand = food.brand
            source = food.source
            self.grams = grams
            per100g = food.per100g
            self.loggedAt = loggedAt
            self.syncID = syncID
            self.syncedDay = syncedDay
        }

        /// The nutrients in the amount eaten.
        var nutrients: NutrientProfile {
            per100g.scaled(byGrams: grams)
        }

        /// Matches entries logged on the same calendar day as `date`.
        static func loggedOnSameDay(as date: Date, calendar: Calendar) -> Predicate<FoodLogEntry> {
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
            return #Predicate<FoodLogEntry> { entry in
                entry.loggedAt >= start && entry.loggedAt < end
            }
        }

        /// Matches entries that haven't been pushed to the server yet.
        static var notSynced: Predicate<FoodLogEntry> {
            #Predicate<FoodLogEntry> { entry in
                entry.syncedDay == nil
            }
        }

        /// Matches entries pushed to the server under `day`.
        static func synced(onDay day: String) -> Predicate<FoodLogEntry> {
            #Predicate<FoodLogEntry> { entry in
                entry.syncedDay == day
            }
        }

        /// Matches entries logged before the calendar day of `date` begins.
        static func loggedBeforeDay(of date: Date, calendar: Calendar) -> Predicate<FoodLogEntry> {
            let start = calendar.startOfDay(for: date)
            return #Predicate<FoodLogEntry> { entry in
                entry.loggedAt < start
            }
        }

        /// Matches entries logged after the calendar day of `date` ends and before the calendar day of `today` begins.
        static func loggedBetweenDay(after date: Date, andDay today: Date, calendar: Calendar) -> Predicate<FoodLogEntry> {
            let dayStart = calendar.startOfDay(for: date)
            let start = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
            let end = calendar.startOfDay(for: today)
            return #Predicate<FoodLogEntry> { entry in
                entry.loggedAt >= start && entry.loggedAt < end
            }
        }
    }
}
