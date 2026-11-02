import Foundation
import Testing
@testable import CalTracker

@Suite(.tags(.networking))
struct OpenFoodFactsClientTests {
    @Test func searchRequestSendsThePage() throws {
        let client = OpenFoodFactsClient(httpClient: MockHTTPClient(data: Data()))

        let first = try queryItems(of: client.makeRequest(for: FoodSearchRequest(query: "biscuit", page: 1)))
        let third = try queryItems(of: client.makeRequest(for: FoodSearchRequest(query: "biscuit", page: 3)))

        #expect(first["page"] == "1")
        #expect(third["page"] == "3")
    }

    @Test func searchReadsPaging() async throws {
        let http = MockHTTPClient(data: try FixtureLoader.data(named: "off_search_page"))

        let page = try await OpenFoodFactsClient(httpClient: http).search(FoodSearchRequest(query: "biscuit"))

        #expect(page.hasMore)
        #expect(page.foods.map(\.name) == ["Parle-G", "Good Day Cashew Cookies", "Fruit Biscuits"])
    }

    @Test func searchOnTheLastPageHasNoMore() async throws {
        let http = MockHTTPClient(data: Data(#"{"hits": [], "page": 4, "page_count": 4}"#.utf8))

        let page = try await OpenFoodFactsClient(httpClient: http).search(FoodSearchRequest(query: "biscuit", page: 4))

        #expect(page.hasMore == false)
    }

    @Test func searchWithoutPagingFieldsHasNoMorePages() async throws {
        let http = MockHTTPClient(data: try FixtureLoader.data(named: "off_search"))

        #expect(try await OpenFoodFactsClient(httpClient: http).search(FoodSearchRequest(query: "nutella")).hasMore == false)
    }

    @Test func productRequestUsesTheV2EndpointAndUserAgent() throws {
        let request = try OpenFoodFactsClient(httpClient: MockHTTPClient(data: Data())).makeProductRequest(code: "3017620422003")

        #expect(request.url?.host() == "world.openfoodfacts.org")
        #expect(request.url?.path() == "/api/v2/product/3017620422003")
        #expect(request.url?.query()?.contains("fields=code%2Cproduct_name%2Cbrands%2Cnutriments") == true)
        #expect(request.value(forHTTPHeaderField: "User-Agent") == OpenFoodFactsClient.userAgent)
    }

    @Test(arguments: ["", "../search", "301 762", "abc?x=1"])
    func productRequestRejectsCodesThatAreNotBarcodes(code: String) {
        #expect(throws: APIError.invalidURL) {
            try OpenFoodFactsClient(httpClient: MockHTTPClient(data: Data())).makeProductRequest(code: code)
        }
    }

    @Test func productResponseMapsToAFoodItem() async throws {
        let http = MockHTTPClient(data: try FixtureLoader.data(named: "off_product"))

        let food = try #require(try await OpenFoodFactsClient(httpClient: http).product(code: "3017620422003"))

        #expect(food.id == "off-3017620422003")
        #expect(food.name == "Nutella")
        #expect(food.brand == "Nutella")
        #expect(food.source == .openFoodFacts)
        #expect(food.per100g.energy == 539)
        #expect(food.per100g.carbohydrates == 57.5)
    }

    @Test func notFoundStatusIsNil() async throws {
        let http = MockHTTPClient(data: try FixtureLoader.data(named: "off_product_missing"))

        #expect(try await OpenFoodFactsClient(httpClient: http).product(code: "0000000000000") == nil)
    }

    @Test func http404IsNil() async throws {
        let http = MockHTTPClient(data: Data(#"{"status": 0}"#.utf8), statusCode: 404)

        #expect(try await OpenFoodFactsClient(httpClient: http).product(code: "123") == nil)
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
}
