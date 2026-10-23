import Foundation
import SwiftData

/// The composition root: owns the app's services and builds feature view models.
struct AppDependencies {
    /// The combined USDA + Open Food Facts search.
    let foodSearch: CombinedFoodSearch

    /// Where logged foods are written.
    let foodLog: any FoodLogging

    /// The person's daily targets and goal.
    let targets: TargetsStore

    /// How long search waits after the last keystroke.
    var searchDebounce: Duration = FoodSearchViewModel.defaultDebounce

    /// Creates a view model for the food search screen.
    func makeSearchViewModel() -> FoodSearchViewModel {
        FoodSearchViewModel(foodSearch: foodSearch, debounce: searchDebounce)
    }

    /// Creates a view model for logging `food`.
    func makeLogFoodViewModel(food: FoodItem) -> LogFoodViewModel {
        LogFoodViewModel(food: food, foodLog: foodLog)
    }

    /// Creates a view model for editing the daily targets.
    func makeTargetsViewModel() -> TargetsViewModel {
        TargetsViewModel(store: targets)
    }

    /// The production dependencies, writing through `modelContext` and the standard user defaults.
    static func live(modelContext: ModelContext) -> AppDependencies {
        let session = URLSession.shared
        return AppDependencies(
            foodSearch: CombinedFoodSearch(
                usda: USDAClient(httpClient: session, configuration: USDAConfiguration(bundle: .main)),
                openFoodFacts: OpenFoodFactsClient(httpClient: session)
            ),
            foodLog: FoodLogStore(modelContext: modelContext),
            targets: TargetsStore(defaults: .standard)
        )
    }

    /// Dependencies backed by the shared in-memory preview container.
    static let preview = live(modelContext: AppModelContainer.preview.mainContext)
}
