import Foundation
import Testing
@testable import CalTracker

@Suite(.tags(.networking))
struct USDAClientTests {
    private func client(_ http: MockHTTPClient) -> USDAClient {
        USDAClient(httpClient: http, configuration: USDAConfiguration(apiKey: "test-key"))
    }

    @Test func foodsRequestPostsIDsInTheAbridgedFormat() throws {
        let request = try client(MockHTTPClient(data: Data())).makeFoodsRequest(fdcIDs: Array(1...25))

        #expect(request.httpMethod == "POST")
        #expect(request.url?.path() == "/fdc/v1/foods")
        #expect(request.url?.query() == "api_key=test-key")
        let body = try #require(request.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["fdcIds"] as? [Int] == Array(1...20))
        #expect(json["format"] as? String == "abridged")
    }

    @Test func foodsResponseMapsToFoodItems() async throws {
        let http = MockHTTPClient(data: try FixtureLoader.data(named: "usda_foods"))

        let foods = try await client(http).foods(fdcIDs: [173_944, 2_346_404])

        #expect(foods.map(\.id) == ["usda-173944", "usda-2346404"])
        let banana = try #require(foods.first)
        #expect(banana.name == "Bananas, raw")
        #expect(banana.source == .usda)
        #expect(banana.per100g.energy == 89)
        #expect(banana.per100g.protein == 1.09)
        #expect(banana.per100g.fiber == 2.6)
    }

    @Test func malformedFoodsResponseIsADecodingError() async {
        let http = MockHTTPClient(data: Data(#"{"not": "a list"}"#.utf8))

        await #expect(throws: APIError.decoding) {
            try await client(http).foods(fdcIDs: [1])
        }
    }
}
