import Foundation

/// Builds requests for the Gramwise backend, so every client of it sends the same headers and JSON.
nonisolated struct GramwiseRequestBuilder: Sendable {
    private let configuration: GramwiseConfiguration

    /// Creates a builder that resolves paths against `configuration`'s base URL.
    init(configuration: GramwiseConfiguration) {
        self.configuration = configuration
    }

    /// Builds a request for `path` under the base URL.
    ///
    /// - Parameters:
    ///   - method: The HTTP method, such as `"GET"` or `"POST"`.
    ///   - path: The route, relative to the base URL, such as `"me/goal"`.
    ///   - query: Query items, percent-encoded strictly so characters such as `+` survive.
    ///   - body: Sent as JSON with `GramwiseJSON`'s date format, when given.
    ///   - accessToken: Sent as a bearer token, when given.
    ///   - timeout: How long to wait for the backend, or `URLRequest`'s default when `nil`.
    /// - Throws: `APIError.invalidURL` when the URL can't be built, or the encoder's error for `body`.
    func makeRequest(
        _ method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: (any Encodable)? = nil,
        accessToken: String? = nil,
        timeout: TimeInterval? = nil
    ) throws -> URLRequest {
        guard var components = URLComponents(
            url: configuration.baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }
        if query.isEmpty == false {
            components.setStrictlyEncodedQueryItems(query)
        }
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        if let timeout {
            request.timeoutInterval = timeout
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try GramwiseJSON.makeEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}
