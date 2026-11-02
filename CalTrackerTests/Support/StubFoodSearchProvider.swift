import Synchronization
@testable import CalTracker

/// A `FoodSearchProvider` that either answers immediately or suspends each search until the test resolves it.
///
/// The controlled mode lets tests order overlapping searches deterministically, without sleeps. Controlled
/// searches are keyed by query and page.
nonisolated final class StubFoodSearchProvider: FoodSearchProvider {
    /// Identifies one controlled search.
    private struct Key: Hashable {
        let query: String
        let page: Int
    }

    private struct State {
        var requests: [FoodSearchRequest] = []
        var pending: [Key: CheckedContinuation<FoodSearchPage, any Error>] = [:]
        var waiters: [(key: Key, occurrence: Int, continuation: CheckedContinuation<Void, Never>)] = []

        /// How many requests for `key` have arrived.
        func count(of key: Key) -> Int {
            requests.count { Key(query: $0.query, page: $0.page) == key }
        }
    }

    /// The canned answer, or `nil` when each search waits for `resolve(_:page:with:)`.
    private let immediateResult: Result<FoodSearchPage, any Error>?
    private let state = Mutex(State())

    /// Creates a provider that answers every search with `result`.
    init(result: Result<FoodSearchPage, any Error>) {
        immediateResult = result
    }

    /// Creates a provider that answers every search with `foods` and no further pages.
    convenience init(foods: [FoodItem]) {
        self.init(result: .success(FoodSearchPage(foods: foods)))
    }

    /// Creates a provider that fails every search with `error`.
    convenience init(error: any Error) {
        self.init(result: .failure(error))
    }

    private init() {
        immediateResult = nil
    }

    /// Creates a provider whose searches suspend until `resolve(_:page:with:)` is called.
    static func controlled() -> StubFoodSearchProvider {
        StubFoodSearchProvider()
    }

    /// Every request received so far, in order.
    var requests: [FoodSearchRequest] {
        state.withLock { $0.requests }
    }

    /// Every query searched so far, in order.
    var receivedQueries: [String] {
        requests.map(\.query)
    }

    func search(_ request: FoodSearchRequest) async throws -> FoodSearchPage {
        if let immediateResult {
            state.withLock { $0.requests.append(request) }
            return try immediateResult.get()
        }

        let key = Key(query: request.query, page: request.page)
        return try await withCheckedThrowingContinuation { continuation in
            let ready = state.withLock { state in
                state.requests.append(request)
                state.pending[key] = continuation
                let count = state.count(of: key)
                let ready = state.waiters.filter { $0.key == key && $0.occurrence <= count }
                state.waiters.removeAll { $0.key == key && $0.occurrence <= count }
                return ready.map(\.continuation)
            }
            ready.forEach { $0.resume() }
        }
    }

    /// Suspends until the `occurrence`th search for `query` and `page` has started, counting from 1.
    func waitForRequest(_ query: String, page: Int = 1, occurrence: Int = 1) async {
        let key = Key(query: query, page: page)
        await withCheckedContinuation { continuation in
            let alreadyReceived = state.withLock { state in
                if state.count(of: key) >= occurrence {
                    return true
                }
                state.waiters.append((key, occurrence, continuation))
                return false
            }
            if alreadyReceived {
                continuation.resume()
            }
        }
    }

    /// Finishes the suspended search for `query` and `page` with `result`.
    func resolve(_ query: String, page: Int = 1, with result: Result<FoodSearchPage, any Error>) {
        let continuation = state.withLock { $0.pending.removeValue(forKey: Key(query: query, page: page)) }
        continuation?.resume(with: result)
    }

    /// Finishes the suspended search for `query` and `page` with `foods`, saying whether more pages follow.
    func resolve(_ query: String, page: Int = 1, foods: [FoodItem], hasMore: Bool = false, brands: [BrandOption] = []) {
        resolve(query, page: page, with: .success(FoodSearchPage(foods: foods, hasMore: hasMore, brands: brands)))
    }
}
