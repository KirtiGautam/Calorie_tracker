import Foundation

/// Talks to the Gramwise backend over HTTP.
nonisolated struct GramwiseClient: GramwiseAPI {
    private let httpClient: any HTTPClient
    private let configuration: GramwiseConfiguration

    /// Creates a client that sends requests through `httpClient` to `configuration`'s backend.
    init(httpClient: any HTTPClient, configuration: GramwiseConfiguration) {
        self.httpClient = httpClient
        self.configuration = configuration
    }

    func signUp(email: String, password: String) async throws -> GramwiseTokenPair {
        let request = try makeRequest("POST", path: "auth/signup", body: GramwiseCredentials(email: email, password: password))
        return try await send(request, decoding: GramwiseTokenPair.self)
    }

    func signIn(email: String, password: String) async throws -> GramwiseTokenPair {
        let request = try makeRequest("POST", path: "auth/login", body: GramwiseCredentials(email: email, password: password))
        return try await send(request, decoding: GramwiseTokenPair.self)
    }

    func refresh(refreshToken: String) async throws -> GramwiseTokenPair {
        let request = try makeRequest("POST", path: "auth/refresh", body: GramwiseRefreshRequest(refreshToken: refreshToken))
        return try await send(request, decoding: GramwiseTokenPair.self)
    }

    func deleteAccount(accessToken: String) async throws {
        let request = try makeRequest("DELETE", path: "me", accessToken: accessToken)
        _ = try await perform(request)
    }

    func goal(accessToken: String) async throws -> GramwiseGoal? {
        let request = try makeRequest("GET", path: "me/goal", accessToken: accessToken)
        do {
            return try await send(request, decoding: GramwiseGoal.self)
        } catch GramwiseAPIError.server(status: 404) {
            return nil
        }
    }

    func putGoal(_ goal: GramwiseGoal, accessToken: String) async throws -> GramwiseGoal {
        let request = try makeRequest("PUT", path: "me/goal", body: goal, accessToken: accessToken)
        return try await send(request, decoding: GramwiseGoal.self)
    }

    func pushChanges(_ changes: GramwiseLogChanges, accessToken: String) async throws -> [GramwiseDailyLog] {
        let request = try makeRequest("POST", path: "daily-logs/changes", body: changes, accessToken: accessToken)
        return try await send(request, decoding: GramwiseChangedDays.self).days
    }

    func dailyLogs(after cursor: String?, accessToken: String) async throws -> GramwiseDailyLogPage {
        let query = cursor.map { [URLQueryItem(name: "cursor", value: $0)] } ?? []
        let request = try makeRequest("GET", path: "daily-logs", query: query, accessToken: accessToken)
        return try await send(request, decoding: GramwiseDailyLogPage.self)
    }

    /// Builds a request for `path` under the base URL, with a JSON body and bearer token when given.
    func makeRequest(
        _ method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: (any Encodable)? = nil,
        accessToken: String? = nil
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

    private func send<Response: Decodable & Sendable>(_ request: URLRequest, decoding type: Response.Type) async throws -> Response {
        try await Self.decode(type, from: try await perform(request))
    }

    /// Performs `request` and returns the body of a 2xx response.
    ///
    /// - Throws: A `GramwiseAPIError` mapped from the error envelope, `.unreachable` when the backend can't be
    ///   reached, or the `URLError` for being offline or timing out.
    private func perform(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await httpClient.data(for: request)
        } catch let error as URLError where Self.unreachableCodes.contains(error.code) {
            throw GramwiseAPIError.unreachable
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw Self.error(status: httpResponse.statusCode, body: data)
        }
        return data
    }

    /// Transport failures that mean the backend itself is down or misconfigured, rather than the device being offline.
    private static let unreachableCodes: Set<URLError.Code> = [
        .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .badServerResponse, .secureConnectionFailed,
    ]

    /// Maps a failure response to an error, using the envelope's stable code when there is one.
    static func error(status: Int, body: Data) -> GramwiseAPIError {
        let code = (try? JSONDecoder().decode(GramwiseErrorEnvelope.self, from: body))?.error.code
        return switch code {
        case "email_taken": .emailTaken
        case "invalid_credentials": .invalidCredentials
        case "invalid_token": .invalidToken
        case "validation_error": .invalidInput
        case "goal_outdated": .goalOutdated
        case "invalid_goal_date": .invalidGoalDate
        case "too_many_foods": .tooManyFoods
        case "invalid_cursor": .invalidCursor
        default: .server(status: status)
        }
    }

    /// Decodes a response off the caller's actor, since a page of days can be large.
    @concurrent
    static func decode<Response: Decodable & Sendable>(_ type: Response.Type, from data: Data) async throws -> Response {
        do {
            return try GramwiseJSON.makeDecoder().decode(type, from: data)
        } catch is DecodingError {
            throw APIError.decoding
        }
    }
}
