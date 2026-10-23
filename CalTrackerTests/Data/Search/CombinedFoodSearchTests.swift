import Foundation
import Testing
@testable import CalTracker

@Suite(.tags(.networking))
struct CombinedFoodSearchTests {
    @Test func returnsBothSourcesWhenBothSucceed() async throws {
        let usdaHTTP = MockHTTPClient(data: try FixtureLoader.data(named: "usda_search"))
        let offHTTP = MockHTTPClient(data: try FixtureLoader.data(named: "off_search"))
        let search = makeSearch(usdaHTTP: usdaHTTP, offHTTP: offHTTP)

        let results = await search.search("banana")

        #expect(try results.usda.get().count == 2)
        #expect(try results.openFoodFacts.get().count == 2)
        #expect(results.errorIfAllFailed == nil)
        #expect(results.hasNoMatches == false)
    }

    @Test func keepsOneSourcesResultsWhenTheOtherFails() async throws {
        let usdaHTTP = MockHTTPClient(error: URLError(.notConnectedToInternet))
        let offHTTP = MockHTTPClient(data: try FixtureLoader.data(named: "off_search"))
        let search = makeSearch(usdaHTTP: usdaHTTP, offHTTP: offHTTP)

        let results = await search.search("nutella")

        #expect(throws: URLError(.notConnectedToInternet)) { try results.usda.get() }
        #expect(try results.openFoodFacts.get().map(\.name) == ["Nutella", "Oat Biscuits"])
        #expect(results.errorIfAllFailed == nil)
    }

    @Test func reportsRateLimitingAsAnAPIError() async throws {
        let usdaHTTP = MockHTTPClient(data: try FixtureLoader.data(named: "usda_search"))
        let offHTTP = MockHTTPClient(data: Data(), statusCode: 429)
        let search = makeSearch(usdaHTTP: usdaHTTP, offHTTP: offHTTP)

        let results = await search.search("nutella")

        #expect(throws: APIError.rateLimited) { try results.openFoodFacts.get() }
        #expect(try results.usda.get().isEmpty == false)
    }

    @Test func reportsTheFirstErrorWhenEverySourceFails() async {
        let search = makeSearch(
            usdaHTTP: MockHTTPClient(error: URLError(.timedOut)),
            offHTTP: MockHTTPClient(data: Data("not json".utf8))
        )

        let results = await search.search("banana")

        #expect(results.errorIfAllFailed is URLError)
        #expect(throws: APIError.decoding) { try results.openFoodFacts.get() }
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
