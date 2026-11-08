/// Looks foods up in USDA or Open Food Facts, routed by each ID's `FoodSource.idPrefix`.
nonisolated struct ProviderFoodLookup: FoodLookup {
    /// The most Open Food Facts lookups in flight at once, to stay polite to its servers.
    static let maxConcurrentProductLookups = 4

    private let usda: USDAClient
    private let openFoodFacts: OpenFoodFactsClient

    /// Creates a lookup that uses `usda` and `openFoodFacts`.
    init(usda: USDAClient, openFoodFacts: OpenFoodFactsClient) {
        self.usda = usda
        self.openFoodFacts = openFoodFacts
    }

    func foods(withIDs ids: Set<String>) async -> [String: FoodItem] {
        let fdcIDs = ids.compactMap { FoodSource.usda.code(fromFoodID: $0).flatMap { Int($0) } }.sorted()
        let codes = ids.compactMap { FoodSource.openFoodFacts.code(fromFoodID: $0) }.sorted()

        async let usdaFoods = usdaFoods(fdcIDs: fdcIDs)
        async let products = products(codes: codes)
        return await usdaFoods.merging(products) { first, _ in first }
    }

    /// Fetches USDA foods in batches of `USDAClient.maxFoodsPerRequest`, one batch at a time to respect the rate limit.
    private func usdaFoods(fdcIDs: [Int]) async -> [String: FoodItem] {
        var found: [String: FoodItem] = [:]
        for batch in fdcIDs.chunked(into: USDAClient.maxFoodsPerRequest) {
            // Cancellation ends the lookup. A failed request doesn't throw it, so it's checked here.
            if Task.isCancelled { break }
            do {
                for food in try await usda.foods(fdcIDs: Array(batch)) {
                    found[food.id] = food
                }
            } catch APIError.rateLimited, APIError.httpStatus(503) {
                // Later batches would be refused too: this client is over its limit, or the backend's shared USDA key
                // is blocked for everyone. The rest fall back to their logged macros.
                break
            } catch {
                // This batch falls back to its logged macros. The next one may still work.
                continue
            }
        }
        return found
    }

    /// Fetches Open Food Facts products, at most `maxConcurrentProductLookups` at a time.
    private func products(codes: [String]) async -> [String: FoodItem] {
        await withTaskGroup(of: FoodItem?.self) { group in
            var pending = codes.makeIterator()
            for _ in 0..<Self.maxConcurrentProductLookups {
                guard let code = pending.next() else { break }
                group.addTask { [openFoodFacts] in try? await openFoodFacts.product(code: code) }
            }

            var found: [String: FoodItem] = [:]
            for await food in group {
                if let food {
                    found[food.id] = food
                }
                if let code = pending.next() {
                    group.addTask { [openFoodFacts] in try? await openFoodFacts.product(code: code) }
                }
            }
            return found
        }
    }
}
