/// Searches USDA and Open Food Facts concurrently and keeps each source's outcome.
nonisolated struct CombinedFoodSearch: Sendable {
    /// The whole-food provider.
    let usda: any FoodSearchProvider

    /// The packaged-product provider.
    let openFoodFacts: any FoodSearchProvider

    /// Fetches each source's next page from `cursor` in parallel.
    ///
    /// A source whose cursor is `nil` has no more pages and isn't asked, which saves both APIs' rate limits.
    /// Each child task returns a `Result` rather than throwing, so a failure in one source never cancels the
    /// other and partial results survive.
    func search(
        _ query: String,
        cursor: FoodSearchCursor = .firstPage
    ) async -> FoodSearchBatch {
        await withTaskGroup(of: (FoodSource, Result<FoodSearchPage, any Error>).self) { group in
            if let page = cursor.usda {
                let request = FoodSearchRequest(query: query, page: page)
                group.addTask { [usda] in
                    await (.usda, Self.outcome(of: usda, for: request))
                }
            }
            if let page = cursor.openFoodFacts {
                let request = FoodSearchRequest(query: query, page: page)
                group.addTask { [openFoodFacts] in
                    await (.openFoodFacts, Self.outcome(of: openFoodFacts, for: request))
                }
            }

            var batch = FoodSearchBatch()
            for await (source, result) in group {
                batch[source] = result
            }
            return batch
        }
    }

    /// Runs one provider's search and captures its success or failure.
    private static func outcome(
        of provider: any FoodSearchProvider,
        for request: FoodSearchRequest
    ) async -> Result<FoodSearchPage, any Error> {
        do {
            return .success(try await provider.search(request))
        } catch {
            return .failure(error)
        }
    }
}
