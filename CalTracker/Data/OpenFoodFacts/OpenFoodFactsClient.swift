import Foundation

/// Searches Open Food Facts for packaged and branded products.
nonisolated struct OpenFoodFactsClient: FoodSearchProvider {
    /// The contact OFF asks every app to include in its User-Agent.
    static let contact = "https://github.com/KirtiGautam/Calorie_tracker"

    /// The User-Agent OFF requires, in the form `AppName/Version (contact)`, with the app's marketing version.
    static let userAgent: String = {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        return "Gramwise/\(version) (\(contact))"
    }()

    /// How many products to request per search.
    static let pageSize = 20

    /// The product fields every request asks for.
    static let fields = "code,product_name,brands,nutriments"

    private let httpClient: any HTTPClient

    /// Creates a client that sends requests through `httpClient`.
    init(httpClient: any HTTPClient) {
        self.httpClient = httpClient
    }

    /// Returns one page of products.
    func search(_ request: FoodSearchRequest) async throws -> FoodSearchPage {
        let urlRequest = try makeRequest(for: request)
        let data = try await httpClient.validatedData(for: urlRequest)
        return try await Self.parse(data)
    }

    /// Builds the search request, including the required User-Agent.
    ///
    /// Uses OFF's Search-a-licious service, since the legacy `/cgi-bin/search.pl` endpoint now returns 404.
    func makeRequest(for request: FoodSearchRequest) throws -> URLRequest {
        try Self.makeGETRequest(host: "search.openfoodfacts.org", path: "/search", queryItems: [
            URLQueryItem(name: "q", value: request.query),
            URLQueryItem(name: "page", value: String(request.page)),
            URLQueryItem(name: "page_size", value: String(Self.pageSize)),
            URLQueryItem(name: "fields", value: Self.fields),
        ])
    }

    /// Returns the product with barcode `code`, or `nil` when OFF doesn't have it or it has no usable nutrients.
    func product(code: String) async throws -> FoodItem? {
        let request = try makeProductRequest(code: code)
        let data: Data
        do {
            data = try await httpClient.validatedData(for: request)
        } catch APIError.httpStatus(404) {
            return nil
        }
        return try await Self.parseProduct(data, code: code)
    }

    /// Builds a product lookup request, including the required User-Agent.
    ///
    /// - Throws: `APIError.invalidURL` when `code` isn't a plain barcode, so it can't change the path.
    func makeProductRequest(code: String) throws -> URLRequest {
        guard code.wholeMatch(of: /[A-Za-z0-9]+/) != nil else { throw APIError.invalidURL }
        return try Self.makeGETRequest(
            host: "world.openfoodfacts.org",
            path: "/api/v2/product/\(code)",
            queryItems: [URLQueryItem(name: "fields", value: Self.fields)]
        )
    }

    /// Builds a GET request for `path` on `host`, with the User-Agent OFF requires.
    private static func makeGETRequest(host: String, path: String, queryItems: [URLQueryItem]) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.setStrictlyEncodedQueryItems(queryItems)

        guard let url = components.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    /// Decodes and maps a product response off the caller's actor.
    @concurrent
    static func parseProduct(_ data: Data, code: String) async throws -> FoodItem? {
        let response = try JSONDecoder().decodeResponse(OFFProductResponse.self, from: data)
        guard response.status == 1, let product = response.product else { return nil }
        // The product's own code is the one to keep, but fall back to the requested one if it's missing.
        return OFFMapper.foodItem(from: OFFSearchResponse.Product(
            code: product.code ?? code,
            productName: product.productName,
            brands: product.brands,
            nutriments: product.nutriments
        ))
    }

    /// Decodes and maps a search response off the caller's actor, since responses can be large.
    @concurrent
    static func parse(_ data: Data) async throws -> FoodSearchPage {
        let response = try JSONDecoder().decodeResponse(OFFSearchResponse.self, from: data)
        return FoodSearchPage(foods: OFFMapper.foodItems(from: response), hasMore: response.hasMore)
    }
}
