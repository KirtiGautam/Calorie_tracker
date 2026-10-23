import Foundation

/// The minimal networking surface the API clients need, so tests can substitute a mock.
nonisolated protocol HTTPClient: Sendable {
    /// Performs `request` and returns the body and response.
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

nonisolated extension URLSession: HTTPClient {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request, delegate: nil)
    }
}

nonisolated extension HTTPClient {
    /// Performs `request` and returns the body when the server answers with a 2xx status.
    ///
    /// - Throws: `APIError.rateLimited` for HTTP 429, `APIError.httpStatus` for other failures,
    ///   `APIError.invalidResponse` for non-HTTP responses, or the underlying transport error.
    func validatedData(for request: URLRequest) async throws -> Data {
        let (data, response) = try await data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300: return data
        case 429: throw APIError.rateLimited
        default: throw APIError.httpStatus(httpResponse.statusCode)
        }
    }
}
