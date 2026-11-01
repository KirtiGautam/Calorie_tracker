/// Looks foods up in USDA or Open Food Facts, routed by the `usda-` or `off-` prefix of each ID.
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
        let fdcIDs = ids.compactMap { id in id.hasPrefix("usda-") ? Int(id.dropFirst(5)) : nil }.sorted()
        let codes = ids.filter { $0.hasPrefix("off-") }.map { String($0.dropFirst(4)) }.sorted()

        async let usdaFoods = usdaFoods(fdcIDs: fdcIDs)
        async let products = products(codes: codes)
        return await usdaFoods.merging(products) { first, _ in first }
    }

    /// Fetches USDA foods in batches of `USDAClient.maxFoodsPerRequest`, one batch at a time to respect the rate limit.
    private func usdaFoods(fdcIDs: [Int]) async -> [String: FoodItem] {
        var found: [String: FoodItem] = [:]
        for start in stride(from: 0, to: fdcIDs.count, by: USDAClient.maxFoodsPerRequest) {
            let batch = Array(fdcIDs[start..<min(start + USDAClient.maxFoodsPerRequest, fdcIDs.count)])
            do {
                for food in try await usda.foods(fdcIDs: batch) {
                    found[food.id] = food
                }
            } catch APIError.rateLimited {
                // Later batches would be refused too. The rest fall back to their logged macros.
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
