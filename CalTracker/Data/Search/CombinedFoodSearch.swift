/// Searches USDA and Open Food Facts concurrently and keeps each source's outcome.
nonisolated struct CombinedFoodSearch: Sendable {
    /// The whole-food provider.
    let usda: any FoodSearchProvider

    /// The packaged-product provider.
    let openFoodFacts: any FoodSearchProvider

    /// Searches both providers in parallel.
    ///
    /// Each child task returns a `Result` rather than throwing, so a failure in one
    /// source never cancels the other and partial results survive.
    func search(_ query: String) async -> FoodSearchResults {
        await withTaskGroup(of: (FoodSource, Result<[FoodItem], any Error>).self) { group in
            group.addTask { [usda] in
                await (.usda, Self.outcome(of: usda, for: query))
            }
            group.addTask { [openFoodFacts] in
                await (.openFoodFacts, Self.outcome(of: openFoodFacts, for: query))
            }

            var results = FoodSearchResults(usda: .success([]), openFoodFacts: .success([]))
            for await (source, result) in group {
                switch source {
                case .usda: results.usda = result
                case .openFoodFacts: results.openFoodFacts = result
                }
            }
            return results
        }
    }

    /// Runs one provider's search and captures its success or failure.
    private static func outcome(of provider: any FoodSearchProvider, for query: String) async -> Result<[FoodItem], any Error> {
        do {
            return .success(try await provider.search(query))
        } catch {
            return .failure(error)
        }
    }
}
