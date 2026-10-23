/// The outcome of searching both databases, kept separate so one failure doesn't hide the other's results.
nonisolated struct FoodSearchResults: Sendable {
    /// Whole foods from USDA FoodData Central.
    var usda: Result<[FoodItem], any Error>

    /// Packaged products from Open Food Facts.
    var openFoodFacts: Result<[FoodItem], any Error>

    /// Both sources' foods in one list, alternating between sources.
    ///
    /// Relevance scores from the two databases aren't comparable, so alternating keeps each
    /// source's own ranking and puts the best matches from both near the top.
    var foods: [FoodItem] {
        let usdaFoods = (try? usda.get()) ?? []
        let offFoods = (try? openFoodFacts.get()) ?? []
        var merged: [FoodItem] = []
        merged.reserveCapacity(usdaFoods.count + offFoods.count)
        for index in 0..<max(usdaFoods.count, offFoods.count) {
            if index < usdaFoods.count { merged.append(usdaFoods[index]) }
            if index < offFoods.count { merged.append(offFoods[index]) }
        }
        return merged
    }

    /// The sources that failed, in display order.
    var failures: [SourceFailure] {
        var failures: [SourceFailure] = []
        if case .failure(let error) = usda {
            failures.append(SourceFailure(source: .usda, error: error))
        }
        if case .failure(let error) = openFoodFacts {
            failures.append(SourceFailure(source: .openFoodFacts, error: error))
        }
        return failures
    }

    /// Whether both sources answered successfully but neither found a food.
    var hasNoMatches: Bool {
        switch (usda, openFoodFacts) {
        case (.success(let usdaFoods), .success(let offFoods)): usdaFoods.isEmpty && offFoods.isEmpty
        default: false
        }
    }

    /// The first error when every source failed, or `nil` when at least one succeeded.
    var errorIfAllFailed: (any Error)? {
        switch (usda, openFoodFacts) {
        case (.failure(let error), .failure): error
        default: nil
        }
    }
}

/// One database that couldn't answer a search.
nonisolated struct SourceFailure: Identifiable, Sendable {
    /// The database that failed.
    let source: FoodSource

    /// Why it failed.
    let error: any Error

    var id: FoodSource { source }
}
