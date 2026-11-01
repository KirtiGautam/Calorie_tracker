import Foundation
import Testing
@testable import CalTracker

@Suite(.tags(.networking))
struct OpenFoodFactsClientTests {
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
}
