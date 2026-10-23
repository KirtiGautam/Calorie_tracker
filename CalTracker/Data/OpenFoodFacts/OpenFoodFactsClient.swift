import Foundation

/// Searches Open Food Facts for packaged and branded products.
nonisolated struct OpenFoodFactsClient: FoodSearchProvider {
    /// The contact OFF asks every app to include in its User-Agent.
    ///
    /// Replace this with a real email or project URL before shipping.
    static let contact = "contact@example.com"

    /// The User-Agent OFF requires, in the form `AppName/Version (contact)`.
    static let userAgent = "CalTracker/0.1 (\(contact))"

    /// How many products to request per search.
    static let pageSize = 20

    private let httpClient: any HTTPClient

    /// Creates a client that sends requests through `httpClient`.
    init(httpClient: any HTTPClient = URLSession.shared) {
        self.httpClient = httpClient
    }

    func search(_ query: String) async throws -> [FoodItem] {
        let request = try makeRequest(query: query)
        let data = try await httpClient.validatedData(for: request)
        return try await Self.parse(data)
    }

    /// Builds the search request, including the required User-Agent.
    ///
    /// Uses OFF's Search-a-licious service, since the legacy `/cgi-bin/search.pl` endpoint now returns 404.
    func makeRequest(query: String) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "search.openfoodfacts.org"
        components.path = "/search"
        components.setStrictlyEncodedQueryItems([
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page_size", value: String(Self.pageSize)),
            URLQueryItem(name: "fields", value: "code,product_name,brands,nutriments"),
        ])

        guard let url = components.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    /// Decodes and maps a search response off the caller's actor, since responses can be large.
    @concurrent
    static func parse(_ data: Data) async throws -> [FoodItem] {
        do {
            let response = try JSONDecoder().decode(OFFSearchResponse.self, from: data)
            return OFFMapper.foodItems(from: response)
        } catch is DecodingError {
            throw APIError.decoding
        }
    }
}
