import Foundation
import Testing
@testable import CalTracker

@Suite(.tags(.networking))
struct CombinedFoodSearchTests {
    @Test func returnsBothSourcesWhenBothSucceed() async throws {
        let usdaHTTP = MockHTTPClient(data: try FixtureLoader.data(named: "usda_search"))
        let offHTTP = MockHTTPClient(data: try FixtureLoader.data(named: "off_search"))
        let search = makeSearch(usdaHTTP: usdaHTTP, offHTTP: offHTTP)

        let batch = await search.search("banana")

        #expect(try batch.usda?.get().foods.count == 2)
        #expect(try batch.openFoodFacts?.get().foods.count == 2)
        let results = FoodSearchResults(firstBatch: batch)
        #expect(results.errorIfAllFailed == nil)
        #expect(results.hasNoMatches == false)
    }

    @Test func keepsOneSourcesResultsWhenTheOtherFails() async throws {
        let usdaHTTP = MockHTTPClient(error: URLError(.notConnectedToInternet))
        let offHTTP = MockHTTPClient(data: try FixtureLoader.data(named: "off_search"))
        let search = makeSearch(usdaHTTP: usdaHTTP, offHTTP: offHTTP)

        let batch = await search.search("nutella")

        #expect(throws: URLError(.notConnectedToInternet)) { try batch.usda?.get() }
        #expect(try batch.openFoodFacts?.get().foods.map(\.name) == ["Nutella", "Oat Biscuits"])
        #expect(FoodSearchResults(firstBatch: batch).errorIfAllFailed == nil)
    }

    @Test func reportsRateLimitingAsAnAPIError() async throws {
        let usdaHTTP = MockHTTPClient(data: try FixtureLoader.data(named: "usda_search"))
        let offHTTP = MockHTTPClient(data: Data(), statusCode: 429)
        let search = makeSearch(usdaHTTP: usdaHTTP, offHTTP: offHTTP)

        let batch = await search.search("nutella")

        #expect(throws: APIError.rateLimited) { try batch.openFoodFacts?.get() }
        #expect(try batch.usda?.get().foods.isEmpty == false)
    }

    @Test func reportsTheFirstErrorWhenEverySourceFails() async {
        let search = makeSearch(
            usdaHTTP: MockHTTPClient(error: URLError(.timedOut)),
            offHTTP: MockHTTPClient(data: Data("not json".utf8))
        )

        let batch = await search.search("banana")

        #expect(FoodSearchResults(firstBatch: batch).errorIfAllFailed is URLError)
        #expect(throws: APIError.decoding) { try batch.openFoodFacts?.get() }
    }

    @Test func sendsTheRequiredHeadersAndQueryParameters() async throws {
        let usdaHTTP = MockHTTPClient(data: try FixtureLoader.data(named: "usda_search"))
        let offHTTP = MockHTTPClient(data: try FixtureLoader.data(named: "off_search"))
        let search = makeSearch(usdaHTTP: usdaHTTP, offHTTP: offHTTP)

        _ = await search.search("rolled oats")

        let offRequest = try #require(offHTTP.requests.first)
        #expect(offRequest.value(forHTTPHeaderField: "User-Agent") == OpenFoodFactsClient.userAgent)
        let offItems = try queryItems(of: offRequest)
        #expect(offRequest.url?.host() == "search.openfoodfacts.org")
        #expect(offItems["q"] == "rolled oats")
        #expect(offItems["page"] == "1")
        #expect(offItems["page_size"] == "20")
        #expect(offItems["fields"] == "code,product_name,brands,nutriments")

        let usdaRequest = try #require(usdaHTTP.requests.first)
        #expect(usdaRequest.httpMethod == "POST")
        #expect(usdaRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(try queryItems(of: usdaRequest) == ["api_key": "TEST_KEY"])
        let usdaBody = try usdaSearchBody(of: usdaRequest)
        #expect(usdaBody["query"] as? String == "rolled oats")
        #expect(usdaBody["dataType"] as? [String] == ["Foundation", "SR Legacy", "Survey (FNDDS)"])
        #expect(usdaBody["pageSize"] as? Int == 20)
        #expect(usdaBody["pageNumber"] as? Int == 1)
    }

    @Test func asksEachSourceForItsOwnNextPage() async {
        let usda = StubFoodSearchProvider(foods: [])
        let openFoodFacts = StubFoodSearchProvider(foods: [])
        let search = CombinedFoodSearch(usda: usda, openFoodFacts: openFoodFacts)

        _ = await search.search("biscuit", cursor: FoodSearchCursor(usda: 3, openFoodFacts: 2))

        #expect(usda.requests.map(\.page) == [3])
        #expect(openFoodFacts.requests.map(\.page) == [2])
    }

    @Test func doesNotAskASourceThatHasNoMorePages() async throws {
        let usda = StubFoodSearchProvider(foods: [])
        let openFoodFacts = StubFoodSearchProvider(foods: [.fixture(id: "off-1", source: .openFoodFacts)])
        let search = CombinedFoodSearch(usda: usda, openFoodFacts: openFoodFacts)

        let batch = await search.search("biscuit", cursor: FoodSearchCursor(usda: nil, openFoodFacts: 2))

        #expect(usda.requests.isEmpty)
        #expect(batch.usda == nil)
        #expect(try batch.openFoodFacts?.get().foods.map(\.id) == ["off-1"])
    }

    @Test func filtersReachOnlyOpenFoodFacts() async {
        let usda = StubFoodSearchProvider(foods: [])
        let openFoodFacts = StubFoodSearchProvider(foods: [])
        let search = CombinedFoodSearch(usda: usda, openFoodFacts: openFoodFacts)
        let filters = FoodSearchFilters(regionEnabled: true, regionCode: "IN", brand: .name("Parle"))

        _ = await search.search("biscuit", filters: filters)

        #expect(usda.requests.map(\.filters) == [FoodSearchFilters()])
        #expect(openFoodFacts.requests.map(\.filters) == [filters])
    }

    @Test func percentEncodesCharactersServersRejectOrMisread() async throws {
        let usdaHTTP = MockHTTPClient(data: try FixtureLoader.data(named: "usda_search"))
        let offHTTP = MockHTTPClient(data: try FixtureLoader.data(named: "off_search"))
        let search = makeSearch(usdaHTTP: usdaHTTP, offHTTP: offHTTP)

        _ = await search.search("M+M")

        // Some USDA servers answer HTTP 400 to any parentheses in the URL, so the criteria travel in the body.
        let usdaRequest = try #require(usdaHTTP.requests.first)
        let usdaQuery = try #require(usdaRequest.url?.query(percentEncoded: true))
        #expect(usdaQuery.contains("(") == false && usdaQuery.contains("%28") == false)
        #expect(try usdaSearchBody(of: usdaRequest)["query"] as? String == "M+M")
        // A raw `+` reads as a space.
        let offQuery = try #require(offHTTP.requests.first?.url?.query(percentEncoded: true))
        #expect(offQuery.contains("q=M%2BM"))
        #expect(try queryItems(of: try #require(offHTTP.requests.first))["q"] == "M+M")
    }

    private func makeSearch(usdaHTTP: MockHTTPClient, offHTTP: MockHTTPClient) -> CombinedFoodSearch {
        CombinedFoodSearch(
            usda: USDAClient(httpClient: usdaHTTP, configuration: USDAConfiguration(apiKey: "TEST_KEY")),
            openFoodFacts: OpenFoodFactsClient(httpClient: offHTTP)
        )
    }

    private func queryItems(of request: URLRequest) throws -> [String: String] {
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        var items: [String: String] = [:]
        for item in components.queryItems ?? [] {
            items[item.name] = item.value
        }
        return items
    }

    private func usdaSearchBody(of request: URLRequest) throws -> [String: Any] {
        let body = try #require(request.httpBody)
        return try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    }
}
