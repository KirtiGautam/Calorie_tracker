import Foundation
import Testing
@testable import CalTracker

struct FoodSearchResultsTests {
    private let usdaFoods = (1...3).map { FoodItem.fixture(id: "usda-\($0)", source: .usda) }
    private let offFoods = (1...2).map { FoodItem.fixture(id: "off-\($0)", source: .openFoodFacts) }

    @Test func firstPageAlternatesBetweenSourcesAndKeepsEachSourcesOrder() {
        let results = FoodSearchResults(firstBatch: batch(usda: .success(page(usdaFoods)), off: .success(page(offFoods))))

        #expect(results.foods.map(\.id) == ["usda-1", "off-1", "usda-2", "off-2", "usda-3"])
        #expect(results.failures.isEmpty)
    }

    @Test func cursorMovesOnForSourcesWithMorePagesAndStopsForTheRest() {
        let results = FoodSearchResults(firstBatch: batch(
            usda: .success(page(usdaFoods, hasMore: true)),
            off: .success(page(offFoods, hasMore: false))
        ))

        #expect(results.cursor == FoodSearchCursor(usda: 2, openFoodFacts: nil))
        #expect(results.canLoadMore)
    }

    @Test func appendKeepsExistingRowsInPlaceAndSkipsFoodsAlreadyListed() {
        var results = FoodSearchResults(firstBatch: batch(
            usda: .success(page(Array(usdaFoods.prefix(2)), hasMore: true)),
            off: .success(page([offFoods[0]], hasMore: true))
        ))
        let firstPage = results.foods

        let failures = results.append(batch(
            usda: .success(page([usdaFoods[1], usdaFoods[2]], hasMore: false)),
            off: .success(page([offFoods[1]], hasMore: true))
        ))

        #expect(failures.isEmpty)
        #expect(Array(results.foods.prefix(firstPage.count)) == firstPage)
        #expect(results.foods.map(\.id) == ["usda-1", "off-1", "usda-2", "off-2", "usda-3"])
        #expect(results.cursor == FoodSearchCursor(usda: nil, openFoodFacts: 3))
    }

    @Test func aFailureOnPageOneStopsThatSourcesPaging() {
        let results = FoodSearchResults(firstBatch: batch(
            usda: .failure(APIError.rateLimited),
            off: .success(page(offFoods, hasMore: true))
        ))

        #expect(results.foods == offFoods)
        #expect(results.failures.map(\.source) == [.usda])
        #expect(results.failures.first?.error as? APIError == .rateLimited)
        #expect(results.cursor == FoodSearchCursor(usda: nil, openFoodFacts: 2))
    }

    @Test func aFailureOnALaterPageKeepsThatSourcesCursorAndAddsTheOtherSource() {
        var results = FoodSearchResults(firstBatch: batch(
            usda: .success(page([usdaFoods[0]], hasMore: true)),
            off: .success(page([offFoods[0]], hasMore: true))
        ))

        let failures = results.append(batch(
            usda: .failure(URLError(.notConnectedToInternet)),
            off: .success(page([offFoods[1]], hasMore: true))
        ))

        #expect(failures.map(\.source) == [.usda])
        #expect(results.foods.map(\.id) == ["usda-1", "off-1", "off-2"])
        #expect(results.cursor == FoodSearchCursor(usda: 2, openFoodFacts: 3))
        #expect(results.failures.isEmpty, "Only page 1 failures are listed above the results")
    }

    @Test func reportsFailuresInDisplayOrderAndTheFirstErrorWhenAllFail() {
        let results = FoodSearchResults(firstBatch: batch(
            usda: .failure(URLError(.timedOut)),
            off: .failure(APIError.decoding)
        ))

        #expect(results.foods.isEmpty)
        #expect(results.failures.map(\.source) == [.usda, .openFoodFacts])
        #expect(results.errorIfAllFailed is URLError)
        #expect(results.canLoadMore == false)
    }

    @Test func hasNoMatchesOnlyWhenBothSourcesAnsweredEmptyWithNothingMore() {
        let empty = FoodSearchResults(firstBatch: batch(usda: .success(page([])), off: .success(page([]))))
        let emptyButMore = FoodSearchResults(firstBatch: batch(usda: .success(page([], hasMore: true)), off: .success(page([]))))
        let emptyWithFailure = FoodSearchResults(firstBatch: batch(usda: .failure(APIError.rateLimited), off: .success(page([]))))

        #expect(empty.hasNoMatches)
        #expect(emptyButMore.hasNoMatches == false)
        #expect(emptyWithFailure.hasNoMatches == false)
    }

    private func page(_ foods: [FoodItem], hasMore: Bool = false) -> FoodSearchPage {
        FoodSearchPage(foods: foods, hasMore: hasMore)
    }

    private func batch(
        usda: Result<FoodSearchPage, any Error>?,
        off: Result<FoodSearchPage, any Error>?
    ) -> FoodSearchBatch {
        FoodSearchBatch(usda: usda, openFoodFacts: off)
    }
}
