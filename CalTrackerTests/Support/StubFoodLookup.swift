import Synchronization
@testable import CalTracker

/// A `FoodLookup` that finds only the foods it was given, and records what it was asked for.
nonisolated final class StubFoodLookup: FoodLookup {
    private let foods: [String: FoodItem]
    private let requests = Mutex<[Set<String>]>([])
    private let hook = Mutex<(@MainActor @Sendable () -> Void)?>(nil)

    /// Creates a lookup that finds `foods` by their IDs and nothing else.
    init(foods: [FoodItem] = []) {
        self.foods = Dictionary(foods.map { ($0.id, $0) }) { first, _ in first }
    }

    /// The ID sets passed to `foods(withIDs:)`, in order.
    var requestedIDs: [Set<String>] {
        requests.withLock { $0 }
    }

    /// Runs `action` on the main actor during every lookup, so tests can act while a sync pass is in flight.
    func onLookup(_ action: @escaping @MainActor @Sendable () -> Void) {
        hook.withLock { $0 = action }
    }

    func foods(withIDs ids: Set<String>) async -> [String: FoodItem] {
        requests.withLock { $0.append(ids) }
        if let action = hook.withLock({ $0 }) {
            await action()
        }
        return foods.filter { ids.contains($0.key) }
    }
}
