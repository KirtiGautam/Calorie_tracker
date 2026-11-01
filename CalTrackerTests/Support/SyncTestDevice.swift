import Foundation
import SwiftData
@testable import CalTracker

/// One simulated device for sync tests: its own in-memory log, defaults, token store, session and engine,
/// talking to a shared `FakeGramwiseAPI`.
final class SyncTestDevice {
    let container = AppModelContainer.make(inMemory: true)
    let isolated: IsolatedDefaults
    let tokenStore: InMemoryTokenStore
    let store: FoodLogStore
    let targets: TargetsStore
    let account: AccountSession
    let engine: SyncEngine

    /// Creates a device signed in with `tokens`, or signed out when they're `nil`.
    ///
    /// Pass `isolated` to start from defaults written earlier, such as by an older version of the app.
    init(
        server: FakeGramwiseAPI,
        tokens: GramwiseTokenPair?,
        isolated: IsolatedDefaults = IsolatedDefaults(),
        lookup: StubFoodLookup = StubFoodLookup(),
        calendar: Calendar = .gmt,
        now: Date = Date(timeIntervalSince1970: 1_800_000_000)
    ) {
        self.isolated = isolated
        tokenStore = InMemoryTokenStore(tokens: tokens)
        store = FoodLogStore(modelContext: container.mainContext)
        targets = TargetsStore(defaults: isolated.defaults)
        account = AccountSession(api: server, tokenStore: tokenStore)
        engine = SyncEngine(
            modelContext: container.mainContext,
            targets: targets,
            account: account,
            api: server,
            foodLookup: lookup,
            defaults: isolated.defaults,
            calendar: calendar,
            debounce: .zero,
            now: { now }
        )
    }

    /// Runs one sync request to completion.
    func sync() async {
        await engine.requestSync().value
    }

    /// Every entry on the device, oldest first.
    func entries() throws -> [FoodLogEntry] {
        try container.mainContext.fetch(FetchDescriptor<FoodLogEntry>(sortBy: [SortDescriptor(\.loggedAt)]))
    }

    /// Every pending deletion on the device.
    func tombstones() throws -> [FoodLogDeletion] {
        try container.mainContext.fetch(FetchDescriptor<FoodLogDeletion>())
    }
}

extension Calendar {
    /// A Gregorian calendar in GMT, so day keys don't depend on the machine running the tests.
    static var gmt: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }
}
