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

    /// Creates a view model for logging `food`.
    func makeLogFoodViewModel(food: FoodItem) -> LogFoodViewModel {
        LogFoodViewModel(food: food, foodLog: foodLog)
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
        let usda = USDAClient(httpClient: session, configuration: USDAConfiguration(bundle: .main))
        let openFoodFacts = OpenFoodFactsClient(httpClient: session)
        let foodLog = FoodLogStore(modelContext: modelContext)
        let targets = TargetsStore(defaults: defaults)
        let api = GramwiseClient(httpClient: session, configuration: GramwiseConfiguration(bundle: .main))
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
            targets: targets,
            searchPreferences: SearchPreferencesStore(defaults: defaults),
            account: account,
            sync: sync
        )
    }

    /// Dependencies backed by the shared in-memory preview container. They stay signed out.
    static let preview = live(modelContext: AppModelContainer.preview.mainContext, tokenStore: InMemoryTokenStore())
}
