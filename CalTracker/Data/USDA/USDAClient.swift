import Foundation

/// Searches USDA FoodData Central for whole foods with full micronutrient data, through the Gramwise backend.
///
/// The backend holds the USDA API key, so the app never has one. It also decides which data types to search and how
/// many foods make a page, so this client only sends what the person is looking for.
nonisolated struct USDAClient: FoodSearchProvider {
    /// The most IDs the backend's `usda/foods` route accepts in one request.
    static let maxFoodsPerRequest = 20

    /// How long to wait for the backend, a little longer than it waits for USDA.
    ///
    /// `CombinedFoodSearch` waits for both sources, so a hung backend would also hold back Open Food Facts' results.
    static let timeout: TimeInterval = 20

    private let httpClient: any HTTPClient
    private let requests: GramwiseRequestBuilder

    /// Creates a client that sends requests through `httpClient` to `configuration`'s backend.
    init(httpClient: any HTTPClient, configuration: GramwiseConfiguration) {
        self.httpClient = httpClient
        self.requests = GramwiseRequestBuilder(configuration: configuration)
    }

    /// Returns one page of whole foods. Filters are ignored: USDA data is US-only and has no brands among these data types.
    func search(_ request: FoodSearchRequest) async throws -> FoodSearchPage {
        let urlRequest = try makeRequest(for: request)
        let data = try await httpClient.validatedData(for: urlRequest)
        return try await Self.parse(data)
    }

    /// Builds the search request for `request`'s query and page.
    ///
    /// It's a POST so the search text stays out of the backend's access logs.
    func makeRequest(for request: FoodSearchRequest) throws -> URLRequest {
        try requests.makeRequest(
            "POST",
            path: "usda/foods/search",
            body: SearchCriteria(query: request.query, page: request.page),
            timeout: Self.timeout
        )
    }

    /// Returns the foods with the given FoodData Central IDs, at most `maxFoodsPerRequest` of them.
    ///
    /// IDs USDA doesn't know are left out of the result.
    func foods(fdcIDs: [Int]) async throws -> [FoodItem] {
        let request = try makeFoodsRequest(fdcIDs: fdcIDs)
        let data = try await httpClient.validatedData(for: request)
        return try await Self.parseFoods(data)
    }

    /// Builds a lookup request for up to `maxFoodsPerRequest` IDs.
    func makeFoodsRequest(fdcIDs: [Int]) throws -> URLRequest {
        try requests.makeRequest(
            "POST",
            path: "usda/foods",
            body: FoodsCriteria(fdcIDs: Array(fdcIDs.prefix(Self.maxFoodsPerRequest))),
            timeout: Self.timeout
        )
    }

    /// The JSON body of a `usda/foods/search` POST request.
    private struct SearchCriteria: Encodable {
        let query: String
        let page: Int
    }

    /// The JSON body of a `usda/foods` POST request.
    private struct FoodsCriteria: Encodable {
        let fdcIDs: [Int]

        private enum CodingKeys: String, CodingKey {
            case fdcIDs = "fdc_ids"
        }
    }

    /// Decodes and maps a search response off the caller's actor.
    @concurrent
    static func parse(_ data: Data) async throws -> FoodSearchPage {
        let response = try JSONDecoder().decodeResponse(USDASearchResponse.self, from: data)
        return FoodSearchPage(foods: USDAMapper.foodItems(from: response), hasMore: response.hasMore)
    }

    /// Decodes and maps a lookup response off the caller's actor.
    ///
    /// The foods have the same shape as search results, apart from the nutrient field names that
    /// `USDASearchResponse.FoodNutrient` also accepts.
    @concurrent
    static func parseFoods(_ data: Data) async throws -> [FoodItem] {
        try JSONDecoder().decodeResponse([USDASearchResponse.Food].self, from: data).compactMap(USDAMapper.foodItem(from:))
    }
}
