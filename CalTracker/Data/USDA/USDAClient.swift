import Foundation

/// Searches USDA FoodData Central for whole foods with full micronutrient data.
nonisolated struct USDAClient: FoodSearchProvider {
    /// How many foods to request per search.
    static let pageSize = 20

    /// The data types to search. Branded foods are excluded because Open Food Facts covers them.
    static let dataTypes = ["Foundation", "SR Legacy", "Survey (FNDDS)"]

    private let httpClient: any HTTPClient
    private let configuration: USDAConfiguration

    /// Creates a client that sends requests through `httpClient` using `configuration`'s key.
    init(httpClient: any HTTPClient, configuration: USDAConfiguration) {
        self.httpClient = httpClient
        self.configuration = configuration
    }

    func search(_ query: String) async throws -> [FoodItem] {
        let request = try makeRequest(query: query)
        let data = try await httpClient.validatedData(for: request)
        return try await Self.parse(data)
    }

    /// Builds the search request.
    ///
    /// The search criteria go in a JSON POST body rather than the query string because some of
    /// USDA's servers intermittently reject parentheses in the URL (even percent-encoded) with
    /// HTTP 400, and `Survey (FNDDS)` always contains them.
    func makeRequest(query: String) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.nal.usda.gov"
        components.path = "/fdc/v1/foods/search"
        components.setStrictlyEncodedQueryItems([
            URLQueryItem(name: "api_key", value: configuration.apiKey),
        ])

        guard let url = components.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(
            SearchCriteria(query: query, dataType: Self.dataTypes, pageSize: Self.pageSize)
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    /// The JSON body of a `foods/search` POST request.
    private struct SearchCriteria: Encodable {
        let query: String
        let dataType: [String]
        let pageSize: Int
    }

    /// Decodes and maps a search response off the caller's actor, since responses can be large.
    @concurrent
    static func parse(_ data: Data) async throws -> [FoodItem] {
        do {
            let response = try JSONDecoder().decode(USDASearchResponse.self, from: data)
            return USDAMapper.foodItems(from: response)
        } catch is DecodingError {
            throw APIError.decoding
        }
    }
}
