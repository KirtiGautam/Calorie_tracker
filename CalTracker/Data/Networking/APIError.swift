/// Failures the food APIs can produce beyond transport errors.
nonisolated enum APIError: Error, Equatable, Sendable {
    /// The request URL couldn't be built.
    case invalidURL

    /// The response wasn't an HTTP response.
    case invalidResponse

    /// The server answered with a non-success status code.
    case httpStatus(Int)

    /// The server rejected the request for exceeding its rate limit.
    case rateLimited

    /// The response body didn't match the expected format.
    case decoding
}
