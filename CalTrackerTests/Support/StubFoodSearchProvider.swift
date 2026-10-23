import Synchronization
@testable import CalTracker

/// A `FoodSearchProvider` that either answers immediately or suspends each search until the test resolves it.
///
/// The controlled mode lets tests order overlapping searches deterministically, without sleeps.
nonisolated final class StubFoodSearchProvider: FoodSearchProvider {
    private struct State {
        var receivedQueries: [String] = []
        var pending: [String: CheckedContinuation<[FoodItem], any Error>] = [:]
        var waiters: [String: CheckedContinuation<Void, Never>] = [:]
    }

    /// The canned answer, or `nil` when each search waits for `resolve(_:with:)`.
    private let immediateResult: Result<[FoodItem], any Error>?
    private let state = Mutex(State())

    /// Creates a provider that answers every search with `result`.
    init(result: Result<[FoodItem], any Error>) {
        immediateResult = result
    }

    private init() {
        immediateResult = nil
    }

    /// Creates a provider whose searches suspend until `resolve(_:with:)` is called.
    static func controlled() -> StubFoodSearchProvider {
        StubFoodSearchProvider()
    }

    /// Every query searched so far, in order.
    var receivedQueries: [String] {
        state.withLock { $0.receivedQueries }
    }

    func search(_ query: String) async throws -> [FoodItem] {
        if let immediateResult {
            state.withLock { $0.receivedQueries.append(query) }
            return try immediateResult.get()
        }

        return try await withCheckedThrowingContinuation { continuation in
            let waiter = state.withLock { state in
                state.receivedQueries.append(query)
                state.pending[query] = continuation
                return state.waiters.removeValue(forKey: query)
            }
            waiter?.resume()
        }
    }

    /// Suspends until a search for `query` has started.
    func waitForRequest(_ query: String) async {
        await withCheckedContinuation { continuation in
            let alreadyReceived = state.withLock { state in
                if state.receivedQueries.contains(query) {
                    return true
                }
                state.waiters[query] = continuation
                return false
            }
            if alreadyReceived {
                continuation.resume()
            }
        }
    }

    /// Finishes the suspended search for `query` with `result`.
    func resolve(_ query: String, with result: Result<[FoodItem], any Error>) {
        let continuation = state.withLock { $0.pending.removeValue(forKey: query) }
        continuation?.resume(with: result)
    }
}
