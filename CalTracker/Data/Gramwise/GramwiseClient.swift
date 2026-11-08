import Foundation

/// Talks to the Gramwise backend over HTTP.
nonisolated struct GramwiseClient: GramwiseAPI {
    private let httpClient: any HTTPClient
    private let requests: GramwiseRequestBuilder

    /// Creates a client that sends requests through `httpClient` to `configuration`'s backend.
    init(httpClient: any HTTPClient, configuration: GramwiseConfiguration) {
        self.httpClient = httpClient
        self.requests = GramwiseRequestBuilder(configuration: configuration)
    }

    func signUp(email: String, password: String) async throws -> GramwiseTokenPair {
        let request = try requests.makeRequest("POST", path: "auth/signup", body: GramwiseCredentials(email: email, password: password))
        return try await send(request, decoding: GramwiseTokenPair.self)
    }

    func signIn(email: String, password: String) async throws -> GramwiseTokenPair {
        let request = try requests.makeRequest("POST", path: "auth/login", body: GramwiseCredentials(email: email, password: password))
        return try await send(request, decoding: GramwiseTokenPair.self)
    }

    func refresh(refreshToken: String) async throws -> GramwiseTokenPair {
        let request = try requests.makeRequest("POST", path: "auth/refresh", body: GramwiseRefreshRequest(refreshToken: refreshToken))
        return try await send(request, decoding: GramwiseTokenPair.self)
    }

    func deleteAccount(accessToken: String) async throws {
        let request = try requests.makeRequest("DELETE", path: "me", accessToken: accessToken)
        _ = try await perform(request)
    }

    func goal(accessToken: String) async throws -> GramwiseGoal? {
        let request = try requests.makeRequest("GET", path: "me/goal", accessToken: accessToken)
        do {
            return try await send(request, decoding: GramwiseGoal.self)
        } catch GramwiseAPIError.server(status: 404) {
            return nil
        }
    }

    func putGoal(_ goal: GramwiseGoal, accessToken: String) async throws -> GramwiseGoal {
        let request = try requests.makeRequest("PUT", path: "me/goal", body: goal, accessToken: accessToken)
        return try await send(request, decoding: GramwiseGoal.self)
    }

    func pushChanges(_ changes: GramwiseLogChanges, accessToken: String) async throws -> [GramwiseDailyLog] {
        let request = try requests.makeRequest("POST", path: "daily-logs/changes", body: changes, accessToken: accessToken)
        return try await send(request, decoding: GramwiseChangedDays.self).days
    }

    func dailyLogs(after cursor: String?, accessToken: String) async throws -> GramwiseDailyLogPage {
        let query = cursor.map { [URLQueryItem(name: "cursor", value: $0)] } ?? []
        let request = try requests.makeRequest("GET", path: "daily-logs", query: query, accessToken: accessToken)
        return try await send(request, decoding: GramwiseDailyLogPage.self)
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
        try GramwiseJSON.makeDecoder().decodeResponse(type, from: data)
    }
}
