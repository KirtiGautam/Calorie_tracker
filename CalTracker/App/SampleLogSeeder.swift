#if DEBUG
import Foundation
import SwiftData

/// Fills the log with sample meals on past days, for trying out day navigation in the simulator.
///
/// Turn it on with the `-seedSampleLog` launch argument (Product › Scheme › Edit Scheme › Run › Arguments).
/// It only exists in Debug builds, never touches today or real entries, and replaces its own entries on every launch,
/// so their dates stay relative to the current day.
enum SampleLogSeeder {
    /// The launch argument that turns seeding on.
    static let launchArgument = "-seedSampleLog"

    /// The prefix on every sample food's ID, so sample entries can be found and replaced.
    static let idPrefix = "sample-"

    /// How many days ago each sample day is. Days 3 and 6 stay empty so the arrows have gaps to skip.
    static let daysAgo = [1, 2, 4, 5, 7]

    /// Seeds `context` when `arguments` contains `launchArgument`.
    static func seedIfRequested(
        into context: ModelContext,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        guard arguments.contains(launchArgument) else { return }
        do {
            try seed(into: context, now: now, calendar: calendar)
        } catch {
            assertionFailure("Couldn't seed the sample log: \(error)")
        }
    }

    /// Removes earlier sample entries, then logs three meals on each of the `daysAgo` days before `now`.
    static func seed(into context: ModelContext, now: Date, calendar: Calendar) throws {
        let prefix = idPrefix
        let existing = try context.fetch(FetchDescriptor<FoodLogEntry>(
            predicate: #Predicate { $0.foodID.starts(with: prefix) }
        ))
        for entry in existing {
            context.delete(entry)
        }

        let today = calendar.startOfDay(for: now)
        for (index, offset) in daysAgo.enumerated() {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            // Vary portions between days so their totals differ.
            let scale = 0.8 + 0.15 * Double(index % 4)
            for meal in meals {
                guard let loggedAt = calendar.date(bySettingHour: meal.hour, minute: meal.minute, second: 0, of: day) else {
                    continue
                }
                for (food, grams) in meal.portions {
                    context.insert(FoodLogEntry(food: food, grams: (grams * scale).rounded(), loggedAt: loggedAt))
                }
            }
        }
        try context.save()
    }

    /// One meal: when it's eaten and how many grams of each food.
    private struct Meal {
        let hour: Int
        let minute: Int
        let portions: [(FoodItem, Double)]
    }

    private static let meals = [
        Meal(hour: 8, minute: 15, portions: [(oats, 70), (banana, 120)]),
        Meal(hour: 13, minute: 0, portions: [(rice, 200), (chicken, 150)]),
        Meal(hour: 19, minute: 45, portions: [(lentils, 250), (yogurt, 150)]),
    ]

    private static let oats = food("oats", "Oats, rolled", energy: 379, protein: 13.2, carbohydrates: 67.7, fat: 6.5)
    private static let banana = food("banana", "Bananas, raw", energy: 89, protein: 1.1, carbohydrates: 22.8, fat: 0.3)
    private static let rice = food("rice", "Rice, white, cooked", energy: 130, protein: 2.7, carbohydrates: 28.2, fat: 0.3)
    private static let chicken = food("chicken", "Chicken breast, grilled", energy: 165, protein: 31, carbohydrates: 0, fat: 3.6)
    private static let lentils = food("lentils", "Lentils, cooked", energy: 116, protein: 9, carbohydrates: 20.1, fat: 0.4)
    private static let yogurt = food("yogurt", "Greek yogurt, plain", energy: 97, protein: 9, carbohydrates: 4, fat: 5)

    private static func food(
        _ id: String,
        _ name: String,
        energy: Double,
        protein: Double,
        carbohydrates: Double,
        fat: Double
    ) -> FoodItem {
        FoodItem(
            id: idPrefix + id,
            name: name,
            brand: nil,
            source: .usda,
            per100g: NutrientProfile(energy: energy, protein: protein, carbohydrates: carbohydrates, fat: fat)
        )
    }
}
#endif
