import Foundation
import Testing
@testable import CalTracker

@Suite(.tags(.networking))
struct ProviderFoodLookupTests {
    private func lookup(usda: MockHTTPClient, openFoodFacts: MockHTTPClient) -> ProviderFoodLookup {
        ProviderFoodLookup(
            usda: USDAClient(httpClient: usda, configuration: USDAConfiguration(apiKey: "test-key")),
            openFoodFacts: OpenFoodFactsClient(httpClient: openFoodFacts)
        )
    }

    @Test func routesEachIDToItsProvider() async throws {
        let usda = MockHTTPClient(data: try FixtureLoader.data(named: "usda_foods"))
        let openFoodFacts = MockHTTPClient(data: try FixtureLoader.data(named: "off_product"))

        let found = await lookup(usda: usda, openFoodFacts: openFoodFacts).foods(withIDs: [
            "usda-173944", "usda-2346404", "off-3017620422003", "sample-oats",
        ])

        #expect(Set(found.keys) == ["usda-173944", "usda-2346404", "off-3017620422003"])
        #expect(usda.requests.count == 1)
        #expect(openFoodFacts.requests.count == 1)
    }

    @Test func batchesUSDAIDsTwentyAtATime() async throws {
        let usda = MockHTTPClient(data: Data("[]".utf8))
        let ids = Set((1...45).map { "usda-\($0)" })

        _ = await lookup(usda: usda, openFoodFacts: MockHTTPClient(data: Data())).foods(withIDs: ids)

        #expect(usda.requests.count == 3)
    }

    @Test func stopsAskingUSDAOnceRateLimited() async throws {
        let usda = MockHTTPClient(data: Data(), statusCode: 429)
        let ids = Set((1...45).map { "usda-\($0)" })

        let found = await lookup(usda: usda, openFoodFacts: MockHTTPClient(data: Data())).foods(withIDs: ids)

        #expect(found.isEmpty)
        #expect(usda.requests.count == 1)
    }

    @Test func failuresLeaveIDsOut() async throws {
        let failing = MockHTTPClient(error: URLError(.notConnectedToInternet))

        let found = await lookup(usda: failing, openFoodFacts: failing).foods(withIDs: ["usda-1", "off-2", "off-3"])

        #expect(found.isEmpty)
    }
}
