import Foundation
import Testing
@testable import CalTracker

@Suite(.tags(.networking))
struct USDAClientTests {
    private func client(_ http: MockHTTPClient) -> USDAClient {
        USDAClient(httpClient: http, configuration: USDAConfiguration(apiKey: "test-key"))
    }

    @Test func searchRequestSendsThePageNumber() throws {
        let request = try client(MockHTTPClient(data: Data())).makeRequest(for: FoodSearchRequest(query: "oats", page: 3))

        let body = try #require(request.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["pageNumber"] as? Int == 3)
        #expect(json["query"] as? String == "oats")
    }

    @Test func searchIgnoresFilters() throws {
        let filters = FoodSearchFilters(regionEnabled: true, regionCode: "IN", brand: .name("Parle"))
        let plain = try client(MockHTTPClient(data: Data())).makeRequest(for: FoodSearchRequest(query: "oats"))
        let filtered = try client(MockHTTPClient(data: Data())).makeRequest(for: FoodSearchRequest(query: "oats", filters: filters))

        let plainBody = try #require(plain.httpBody)
        let filteredBody = try #require(filtered.httpBody)
        // JSONEncoder doesn't promise a key order, so the bodies are compared as objects.
        let plainJSON = try #require(try JSONSerialization.jsonObject(with: plainBody) as? NSDictionary)
        let filteredJSON = try #require(try JSONSerialization.jsonObject(with: filteredBody) as? NSDictionary)
        #expect(plainJSON == filteredJSON)
    }

    @Test func searchReportsMorePagesUntilTheLast() async throws {
        let http = MockHTTPClient(data: try FixtureLoader.data(named: "usda_search_page"))

        let page = try await client(http).search(FoodSearchRequest(query: "banana"))

        #expect(page.hasMore)
        #expect(page.foods.count == 2)
        #expect(page.brands.isEmpty)
    }

    @Test func searchReportsNoMorePagesOnTheLastPage() async throws {
        let http = MockHTTPClient(data: try FixtureLoader.data(named: "usda_search"))

        #expect(try await client(http).search(FoodSearchRequest(query: "banana")).hasMore == false)
    }

    @Test func searchWithoutPagingFieldsHasNoMorePages() async throws {
        let http = MockHTTPClient(data: Data(#"{"foods": []}"#.utf8))

        #expect(try await client(http).search(FoodSearchRequest(query: "banana")).hasMore == false)
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
