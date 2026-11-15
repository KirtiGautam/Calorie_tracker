import Foundation
import SwiftData

/// The composition root: owns the app's services and builds feature view models.
struct AppDependencies {
    /// The combined USDA + Open Food Facts search.
    let foodSearch: CombinedFoodSearch

    /// Where logged foods are written.
    let foodLog: any FoodLogging

    /// Where logged foods are read back, for quick add.
    let foodHistory: any FoodHistory

    /// The foods the person entered themselves.
    let customFoods: any CustomFoodStoring

    /// The person's daily targets and goal.
    let targets: TargetsStore

    /// The saved search country filter.
    let searchPreferences: SearchPreferencesStore

    /// The optional Gramwise account.
    let account: AccountSession

    /// Backs the log and goal up to the account and restores them.
    let sync: SyncEngine

    /// Creates a view model for the food search screen.
    func makeSearchViewModel() -> FoodSearchViewModel {
        FoodSearchViewModel(foodSearch: foodSearch, preferences: searchPreferences)
    }

    /// Creates a view model for the foods the person logs most often, shown on the search screen.
    func makeFrequentFoodsViewModel() -> FrequentFoodsViewModel {
        FrequentFoodsViewModel(history: foodHistory, foodLog: foodLog)
    }

    /// Creates a view model for logging `food`, starting at `grams`.
    func makeLogFoodViewModel(food: FoodItem, grams: Double = LogFoodViewModel.defaultGrams) -> LogFoodViewModel {
        LogFoodViewModel(food: food, foodLog: foodLog, grams: grams)
    }

    /// Creates a view model for the person's own foods, listed on the search screen.
    func makeCustomFoodsViewModel() -> CustomFoodsViewModel {
        CustomFoodsViewModel(store: customFoods)
    }

    /// Creates a view model for entering a custom food, with its name starting as `name`.
    func makeCustomFoodViewModel(name: String) -> CustomFoodViewModel {
        CustomFoodViewModel(store: customFoods, name: name)
    }

    /// Creates a view model for editing the daily targets.
    func makeTargetsViewModel() -> TargetsViewModel {
        TargetsViewModel(store: targets)
    }

    /// Creates a view model for the account sheet.
    func makeAccountViewModel() -> AccountViewModel {
        AccountViewModel(account: account, sync: sync)
    }

    /// The production dependencies, writing through `modelContext` and `defaults`.
    ///
    /// - Parameter tokenStore: Where the account's tokens are kept. The Keychain by default.
    static func live(
        modelContext: ModelContext,
        tokenStore: any TokenStoring = KeychainTokenStore(),
        defaults: UserDefaults = .standard
    ) -> AppDependencies {
        let session = URLSession.shared
        let backend = GramwiseConfiguration(bundle: .main)
        let usda = USDAClient(httpClient: session, configuration: backend)
        let openFoodFacts = OpenFoodFactsClient(httpClient: session)
        let foodLog = FoodLogStore(modelContext: modelContext)
        let targets = TargetsStore(defaults: defaults)
        let api = GramwiseClient(httpClient: session, configuration: backend)
        let account = AccountSession(api: api, tokenStore: tokenStore)
        let sync = SyncEngine(
            modelContext: modelContext,
            targets: targets,
            account: account,
            api: api,
            foodLookup: ProviderFoodLookup(usda: usda, openFoodFacts: openFoodFacts),
            defaults: defaults
        )
        // The stores are created before the engine, so they're connected to it here.
        foodLog.onChange = { [weak sync] in sync?.scheduleSync() }
        targets.onChange = { [weak sync] in sync?.scheduleSync() }

        return AppDependencies(
            foodSearch: CombinedFoodSearch(usda: usda, openFoodFacts: openFoodFacts),
            foodLog: foodLog,
            foodHistory: foodLog,
            customFoods: CustomFoodStore(modelContext: modelContext),
            targets: targets,
            searchPreferences: SearchPreferencesStore(defaults: defaults),
            account: account,
            sync: sync
        )
    }

    /// Dependencies backed by the shared in-memory preview container. They stay signed out.
    static let preview = live(modelContext: AppModelContainer.preview.mainContext, tokenStore: InMemoryTokenStore())
}
