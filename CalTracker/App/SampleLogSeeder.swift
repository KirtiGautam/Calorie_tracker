#if DEBUG
import Foundation
import SwiftData

/// Fills the log with two weeks of realistic meals, once, for trying out day navigation and sync in the simulator.
///
/// Turn it on with the `-seedSampleLog` launch argument (Product › Scheme › Edit Scheme › Run › Arguments).
/// It only exists in Debug builds and never touches today. The foods are real USDA foods, so the entries are
/// ordinary entries: they sync, and they can be edited or deleted like any other. Seeding runs once per install;
/// launch with `-sampleLog.seeded NO` to seed again.
enum SampleLogSeeder {
    /// The launch argument that turns seeding on.
    static let launchArgument = "-seedSampleLog"

    /// The `UserDefaults` key that records seeding has run.
    static let seededKey = "sampleLog.seeded"

    /// The prefix on the food IDs earlier versions of the seeder used. Those entries never sync, so they're removed.
    static let legacyIDPrefix = "sample-"

    /// How many days ago each sample day is. Days 3, 6 and 10 stay empty so the arrows have gaps to skip.
    static let daysAgo = [1, 2, 4, 5, 7, 8, 9, 11, 12, 13, 14]

    /// Seeds `context` when `arguments` contains `launchArgument` and it hasn't been seeded before.
    static func seedIfRequested(
        into context: ModelContext,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        defaults: UserDefaults = .standard,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        guard arguments.contains(launchArgument), defaults.bool(forKey: seededKey) == false else { return }
        do {
            try seed(into: context, now: now, calendar: calendar)
            defaults.set(true, forKey: seededKey)
        } catch {
            assertionFailure("Couldn't seed the sample log: \(error)")
        }
    }

    /// Removes legacy sample entries, then logs a day of meals on each of the `daysAgo` days before `now`.
    ///
    /// Days that already have entries are skipped, so real logging is never mixed with sample meals.
    static func seed(into context: ModelContext, now: Date, calendar: Calendar) throws {
        let prefix = legacyIDPrefix
        let legacy = try context.fetch(FetchDescriptor<FoodLogEntry>(
            predicate: #Predicate { $0.foodID.starts(with: prefix) }
        ))
        for entry in legacy {
            context.delete(entry)
        }

        let today = calendar.startOfDay(for: now)
        for (index, offset) in daysAgo.enumerated() {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let existing = try context.fetchCount(FetchDescriptor(
                predicate: FoodLogEntry.loggedOnSameDay(as: day, calendar: calendar)
            ))
            guard existing == 0 else { continue }

            // Rotate through the menus at different rates so no two days are the same.
            let meals = [
                breakfasts[index % breakfasts.count],
                lunches[(index + 1) % lunches.count],
                snacks[index % snacks.count],
                dinners[(index * 2) % dinners.count],
            ]
            // Vary portions between days so their totals differ.
            let scale = 0.85 + 0.1 * Double(index % 4)
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

    private static let breakfasts = [
        Meal(hour: 7, minute: 45, portions: [(oats, 60), (milk, 200), (banana, 110)]),
        Meal(hour: 8, minute: 10, portions: [(eggs, 100), (bread, 70), (spinach, 40)]),
        Meal(hour: 8, minute: 30, portions: [(yogurt, 170), (oats, 40), (apple, 150)]),
    ]

    private static let lunches = [
        Meal(hour: 12, minute: 45, portions: [(rice, 200), (chicken, 150), (broccoli, 100)]),
        Meal(hour: 13, minute: 15, portions: [(bread, 80), (cheddar, 30), (hummus, 50), (spinach, 30)]),
        Meal(hour: 13, minute: 0, portions: [(lentils, 250), (rice, 150)]),
        Meal(hour: 12, minute: 30, portions: [(potato, 250), (chicken, 120), (broccoli, 80)]),
    ]

    private static let snacks = [
        Meal(hour: 16, minute: 0, portions: [(apple, 180), (peanutButter, 30)]),
        Meal(hour: 16, minute: 30, portions: [(yogurt, 150)]),
        Meal(hour: 15, minute: 45, portions: [(banana, 120)]),
    ]

    private static let dinners = [
        Meal(hour: 19, minute: 30, portions: [(chicken, 160), (potato, 200), (broccoli, 100)]),
        Meal(hour: 20, minute: 0, portions: [(lentils, 300), (rice, 150), (spinach, 60)]),
        Meal(hour: 19, minute: 45, portions: [(eggs, 150), (bread, 60), (cheddar, 25)]),
    ]

    private static let oats = food(2346396, "Oats, whole grain, rolled, old fashioned", 381.6, 13.5, 68.7, 5.9)
    private static let milk = food(746782, "Milk, whole, 3.25% milkfat, with added vitamin D", 60, 3.27, 4.63, 3.2)
    private static let banana = food(1105314, "Bananas, ripe and slightly ripe, raw", 97, 0.74, 23, 0.29)
    private static let eggs = food(748967, "Eggs, Grade A, Large, egg whole", 148, 12.4, 0.96, 9.96)
    private static let bread = food(335240, "Bread, whole-wheat, commercially prepared", 254, 12.3, 43.1, 3.55)
    private static let spinach = food(1999633, "Spinach, mature", 27.6, 2.91, 2.64, 0.6)
    private static let yogurt = food(2259794, "Yogurt, Greek, plain, whole milk", 93.7, 8.78, 4.75, 4.39)
    private static let apple = food(1105781, "Apples, gala, with skin, raw", 61, 0.13, 14.8, 0.15)
    private static let rice = food(168878, "Rice, white, long-grain, regular, enriched, cooked", 130, 2.69, 28.17, 0.28)
    private static let chicken = food(
        331960, "Chicken, broiler or fryers, breast, skinless, boneless, meat only, cooked, braised", 166, 32.1, 0, 3.24
    )
    private static let broccoli = food(747447, "Broccoli, raw", 31, 2.57, 6.27, 0.34)
    private static let cheddar = food(328637, "Cheese, cheddar", 408, 23.3, 2.44, 34)
    private static let hummus = food(321358, "Hummus, commercial", 229, 7.35, 14.9, 17.1)
    private static let lentils = food(172421, "Lentils, mature seeds, cooked, boiled, without salt", 116, 9.02, 20.13, 0.38)
    private static let potato = food(170030, "Potatoes, Russet, flesh and skin, baked", 95, 2.63, 21.44, 0.13)
    private static let peanutButter = food(324860, "Peanut butter, smooth style, with salt", 597, 22.5, 22.3, 51.1)

    /// A USDA food with the given FoodData Central ID and macros per 100 g.
    private static func food(
        _ fdcID: Int,
        _ name: String,
        _ energy: Double,
        _ protein: Double,
        _ carbohydrates: Double,
        _ fat: Double
    ) -> FoodItem {
        FoodItem(
            id: "usda-\(fdcID)",
            name: name,
            brand: nil,
            source: .usda,
            per100g: NutrientProfile(energy: energy, protein: protein, carbohydrates: carbohydrates, fat: fat)
        )
    }
}
#endif
