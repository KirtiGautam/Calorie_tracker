import Foundation
import Testing
@testable import CalTracker

@Suite(.tags(.networking))
struct USDAClientTests {
    private func client(_ http: MockHTTPClient) -> USDAClient {
        USDAClient(httpClient: http, configuration: GramwiseConfiguration(baseURL: URL(string: "https://api.example.com") ?? URL(filePath: "/")))
    }

    @Test func searchRequestGoesToTheBackendWithOnlyTheQueryAndPage() throws {
        let request = try client(MockHTTPClient(data: Data())).makeRequest(for: FoodSearchRequest(query: "oats", page: 3))

        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://api.example.com/usda/foods/search")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.timeoutInterval == USDAClient.timeout)
        let body = try #require(request.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: AnyHashable])
        #expect(json == ["query": "oats", "page": 3])
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

    @Test func foodsRequestGoesToTheBackendWithAtMostTwentyIDs() throws {
        let request = try client(MockHTTPClient(data: Data())).makeFoodsRequest(fdcIDs: Array(1...25))

        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://api.example.com/usda/foods")
        let body = try #require(request.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: [Int]])
        #expect(json == ["fdc_ids": Array(1...20)])
    }

    @Test func requestsCarryNoAPIKey() throws {
        let usda = client(MockHTTPClient(data: Data()))
        let requests = [
            try usda.makeRequest(for: FoodSearchRequest(query: "oats")),
            try usda.makeFoodsRequest(fdcIDs: [1]),
        ]

        for request in requests {
            #expect(request.url?.query() == nil)
            #expect(Set((request.allHTTPHeaderFields ?? [:]).keys) == ["Content-Type", "Accept"])
        }
    }

    @Test func rateLimitedResponsesAreReportedAsRateLimited() async {
        let http = MockHTTPClient(data: MockHTTPClient.envelope(code: "rate_limited"), statusCode: 429)

        await #expect(throws: APIError.rateLimited) {
            try await client(http).search(FoodSearchRequest(query: "banana"))
        }
    }

    @Test func backendFailuresAreReportedByStatus() async {
        let http = MockHTTPClient(data: MockHTTPClient.envelope(code: "usda_unavailable"), statusCode: 502)

        await #expect(throws: APIError.httpStatus(502)) {
            try await client(http).foods(fdcIDs: [1])
        }
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
