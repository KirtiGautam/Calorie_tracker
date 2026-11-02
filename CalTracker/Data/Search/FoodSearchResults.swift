/// The results of one search, growing page by page as the person scrolls.
///
/// Each page's two sources are merged by alternating and added to the end, so rows already on screen never move.
nonisolated struct FoodSearchResults: Sendable {
    /// Both sources' foods in one list.
    ///
    /// Relevance scores from the two databases aren't comparable, so alternating keeps each
    /// source's own ranking and puts the best matches from both near the top.
    private(set) var foods: [FoodItem] = []

    /// The next page to fetch from each source.
    private(set) var cursor = FoodSearchCursor.firstPage

    /// The sources that failed on page 1, in display order. Those sources don't page any further.
    let failures: [SourceFailure]

    /// The most common Open Food Facts brands for the search, from page 1.
    let brands: [BrandOption]

    /// The first error when every source failed on page 1, or `nil` when at least one succeeded.
    let errorIfAllFailed: (any Error)?

    /// The IDs in `foods`, so a food that shows up again on a later page is skipped.
    private var foodIDs: Set<String> = []

    /// Starts the results from page 1 of each source.
    ///
    /// A source that failed or wasn't asked stops paging, and its failure is kept in `failures`.
    init(firstBatch batch: FoodSearchBatch) {
        let failures = FoodSource.allCases.compactMap { source -> SourceFailure? in
            guard case .failure(let error) = batch[source] else { return nil }
            return SourceFailure(source: source, error: error)
        }
        self.failures = failures
        brands = (try? batch.openFoodFacts?.get())?.brands ?? []
        errorIfAllFailed = failures.count == FoodSource.allCases.count ? failures.first?.error : nil

        for source in FoodSource.allCases where batch[source] == nil || failures.contains(where: { $0.source == source }) {
            cursor[source] = nil
        }
        append(batch)
    }

    /// Whether both sources answered page 1 but neither found a food, and there's nothing more to load.
    var hasNoMatches: Bool {
        failures.isEmpty && foods.isEmpty && cursor.hasMore == false
    }

    /// Whether at least one source has another page to load.
    var canLoadMore: Bool {
        cursor.hasMore
    }

    /// Adds a later page to the end of `foods`, skipping foods already listed.
    ///
    /// A source that succeeded moves its cursor on, or stops once it has no more pages. A source that
    /// failed keeps its cursor, so the same page can be tried again.
    ///
    /// - Returns: The sources that failed on this page.
    @discardableResult
    mutating func append(_ batch: FoodSearchBatch) -> [SourceFailure] {
        var failures: [SourceFailure] = []
        var pages: [[FoodItem]] = []
        for source in FoodSource.allCases {
            switch batch[source] {
            case .success(let page):
                if let current = cursor[source] {
                    cursor[source] = page.hasMore ? current + 1 : nil
                }
                pages.append(page.foods)
            case .failure(let error):
                failures.append(SourceFailure(source: source, error: error))
            case nil:
                break
            }
        }

        let longest = pages.map(\.count).max() ?? 0
        for index in 0..<longest {
            for page in pages where index < page.count {
                let food = page[index]
                if foodIDs.insert(food.id).inserted {
                    foods.append(food)
                }
            }
        }
        return failures
    }
}
