import Foundation

/// Searches Open Food Facts for packaged and branded products.
nonisolated struct OpenFoodFactsClient: FoodSearchProvider {
    /// The contact OFF asks every app to include in its User-Agent.
    static let contact = "https://github.com/KirtiGautam/Calorie_tracker"

    /// The User-Agent OFF requires, in the form `AppName/Version (contact)`.
    static let userAgent = "Gramwise/0.1 (\(contact))"

    /// How many products to request per search.
    static let pageSize = 20

    private let httpClient: any HTTPClient

    /// Creates a client that sends requests through `httpClient`.
    init(httpClient: any HTTPClient) {
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

        var components = URLComponents()
        components.scheme = "https"
        components.host = "world.openfoodfacts.org"
        components.path = "/api/v2/product/\(code)"
        components.setStrictlyEncodedQueryItems([
            URLQueryItem(name: "fields", value: "code,product_name,brands,nutriments"),
        ])

        guard let url = components.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    /// Decodes and maps a product response off the caller's actor.
    @concurrent
    static func parseProduct(_ data: Data, code: String) async throws -> FoodItem? {
        let response: OFFProductResponse
        do {
            response = try JSONDecoder().decode(OFFProductResponse.self, from: data)
        } catch is DecodingError {
            throw APIError.decoding
        }
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
    static func parse(_ data: Data) async throws -> [FoodItem] {
        do {
            let response = try JSONDecoder().decode(OFFSearchResponse.self, from: data)
            return OFFMapper.foodItems(from: response)
        } catch is DecodingError {
            throw APIError.decoding
        }
    }
}
