import Foundation
import Testing
@testable import CalTracker

struct FoodSearchResultsTests {
    private let usdaFoods = (1...3).map { FoodItem.fixture(id: "usda-\($0)", source: .usda) }
    private let offFoods = (1...2).map { FoodItem.fixture(id: "off-\($0)", source: .openFoodFacts) }

    @Test func mergesBothSourcesIntoOneListAlternatingAndKeepingEachSourcesOrder() {
        let results = FoodSearchResults(usda: .success(usdaFoods), openFoodFacts: .success(offFoods))

        #expect(results.foods.map(\.id) == ["usda-1", "off-1", "usda-2", "off-2", "usda-3"])
        #expect(results.failures.isEmpty)
    }

    @Test func listsOnlyTheSuccessfulSourceAndReportsTheFailedOne() {
        let results = FoodSearchResults(usda: .failure(APIError.rateLimited), openFoodFacts: .success(offFoods))

        #expect(results.foods == offFoods)
        #expect(results.failures.map(\.source) == [.usda])
        #expect(results.failures.first?.error as? APIError == .rateLimited)
    }

    @Test func reportsFailuresInDisplayOrder() {
        let results = FoodSearchResults(
            usda: .failure(URLError(.timedOut)),
            openFoodFacts: .failure(APIError.decoding)
        )

        #expect(results.foods.isEmpty)
        #expect(results.failures.map(\.source) == [.usda, .openFoodFacts])
    }
}
