import Foundation
import Testing
@testable import CalTracker

@Suite(.tags(.networking))
struct GramwiseClientTests {
    private let configuration = GramwiseConfiguration(baseURL: URL(string: "https://api.example.com") ?? URL(filePath: "/"))

    private func client(_ http: MockHTTPClient) -> GramwiseClient {
        GramwiseClient(httpClient: http, configuration: configuration)
    }

    private func jsonBody(of request: URLRequest?) throws -> [String: Any] {
        let body = try #require(request?.httpBody)
        return try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    @Test func signUpPostsCredentialsAndDecodesTokens() async throws {
        let http = MockHTTPClient(data: try FixtureLoader.data(named: "gramwise_tokens"), statusCode: 201)

        let tokens = try await client(http).signUp(email: "ada@example.com", password: "correct horse")

        let request = try #require(http.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://api.example.com/auth/signup")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        let body = try jsonBody(of: request)
        #expect(body["email"] as? String == "ada@example.com")
        #expect(body["password"] as? String == "correct horse")
        #expect(tokens.accessToken == "test-access-token")
        #expect(tokens.refreshToken == "test-refresh-token")
        #expect(tokens.user.email == "ada@example.com")
        #expect(tokens.user.id == UUID(uuidString: "148a1950-9ea0-4a7c-af35-126a8707de58"))
    }

    @Test func pushSendsBearerTokenAndFlatItems() async throws {
        let http = MockHTTPClient(data: Data(#"{"days": []}"#.utf8))
        let entryID = UUID()
        let loggedAt = try Date("2026-10-29T08:15:00Z", strategy: .iso8601).addingTimeInterval(0.25)
        let food = GramwiseLoggedFood(
            entryID: entryID,
            foodID: "usda-173944",
            name: "Bananas, raw",
            grams: 120,
            loggedAt: loggedAt,
            energyKcal: 106.8,
            proteinG: nil,
            carbsG: 27.4,
            fatG: 0.4
        )
        let changes = GramwiseLogChanges(
            added: [GramwiseAddedFood(logDate: "2026-10-29", food: food)],
            removed: [GramwiseRemovedFood(logDate: "2026-10-28", entryID: entryID)]
        )

        _ = try await client(http).pushChanges(changes, accessToken: "abc")

        let request = try #require(http.requests.first)
        #expect(request.url?.path() == "/daily-logs/changes")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer abc")
        let body = try jsonBody(of: request)
        let added = try #require((body["added"] as? [[String: Any]])?.first)
        #expect(added["log_date"] as? String == "2026-10-29")
        #expect(added["entry_id"] as? String == entryID.uuidString)
        #expect(added["food_id"] as? String == "usda-173944")
        #expect(added["logged_at"] as? String == "2026-10-29T08:15:00.250Z")
        // Unknown macros are left out, which the server reads as null.
        #expect(added["protein_g"] == nil)
        let removed = try #require((body["removed"] as? [[String: Any]])?.first)
        #expect(removed["log_date"] as? String == "2026-10-28")
    }

    @Test func dailyLogsSendsCursorAndDecodesMicrosecondDates() async throws {
        let http = MockHTTPClient(data: try FixtureLoader.data(named: "gramwise_daily_logs"))

        let page = try await client(http).dailyLogs(after: "abc+/=", accessToken: "token")

        let url = try #require(http.requests.first?.url)
        #expect(url.path() == "/daily-logs")
        #expect(url.query() == "cursor=abc%2B%2F%3D")
        #expect(page.days.map(\.logDate) == ["2026-10-28", "2026-10-29", "2026-10-27"])
        #expect(page.hasMore == false)
        #expect(page.nextCursor?.isEmpty == false)
        let banana = try #require(page.days.first?.foods.first)
        #expect(banana.loggedAt == (try Date("2026-10-28T08:15:00Z", strategy: .iso8601)).addingTimeInterval(0.25))
        #expect(page.days[0].foods[1].fatG == nil)
        #expect(page.days[2].foods.isEmpty)
    }

    @Test func pullWithoutCursorHasNoQuery() async throws {
        let http = MockHTTPClient(data: try FixtureLoader.data(named: "gramwise_daily_logs"))

        _ = try await client(http).dailyLogs(after: nil, accessToken: "token")

        #expect(http.requests.first?.url?.query() == nil)
    }

    @Test func goalRoundTripsWithExplicitNulls() async throws {
        let http = MockHTTPClient(data: Data(#"""
        {"goal": "cut", "energy_kcal": 1800, "protein_g": null, "carbs_g": null, "fat_g": 60, "updated_at": "2026-10-29T08:00:00.123456Z", "effective_from": "2026-10-29"}
        """#.utf8))
        let goal = GramwiseGoal(goal: .cut, targets: DailyTargets(energy: 1_800, fat: 60), updatedAt: .now, effectiveFrom: "2026-10-29")

        let stored = try await client(http).putGoal(goal, accessToken: "token")

        let body = try jsonBody(of: http.requests.first)
        #expect(body["protein_g"] is NSNull)
        #expect(body["goal"] as? String == "cut")
        #expect(body["effective_from"] as? String == "2026-10-29")
        #expect(http.requests.first?.httpMethod == "PUT")
        #expect(stored.targets == DailyTargets(energy: 1_800, fat: 60))
        #expect(stored.effectiveFrom == "2026-10-29")
    }

    @Test func missingGoalIsNil() async throws {
        let http = MockHTTPClient(data: MockHTTPClient.envelope(code: "goal_not_found"), statusCode: 404)

        #expect(try await client(http).goal(accessToken: "token") == nil)
    }

    @Test(arguments: [
        ("email_taken", 409, GramwiseAPIError.emailTaken),
        ("invalid_credentials", 401, .invalidCredentials),
        ("invalid_token", 401, .invalidToken),
        ("validation_error", 422, .invalidInput),
        ("goal_outdated", 409, .goalOutdated),
        ("invalid_goal_date", 422, .invalidGoalDate),
        ("too_many_foods", 422, .tooManyFoods),
        ("invalid_cursor", 422, .invalidCursor),
        ("internal_error", 500, .server(status: 500)),
    ])
    func mapsTheErrorEnvelope(code: String, status: Int, expected: GramwiseAPIError) async throws {
        let http = MockHTTPClient(data: MockHTTPClient.envelope(code: code), statusCode: status)

        await #expect(throws: expected) {
            try await client(http).signIn(email: "ada@example.com", password: "x")
        }
    }

    @Test func emailTakenFixtureMapsToEmailTaken() async throws {
        let http = MockHTTPClient(data: try FixtureLoader.data(named: "gramwise_error_email_taken"), statusCode: 409)

        await #expect(throws: GramwiseAPIError.emailTaken) {
            try await client(http).signUp(email: "ada@example.com", password: "correct horse")
        }
    }

    @Test func nonEnvelopeFailureMapsToStatus() async throws {
        let http = MockHTTPClient(data: Data("Bad Gateway".utf8), statusCode: 502)

        await #expect(throws: GramwiseAPIError.server(status: 502)) {
            try await client(http).goal(accessToken: "token")
        }
    }

    @Test func unreachableBackendIsReported() async throws {
        let http = MockHTTPClient(error: URLError(.cannotConnectToHost))

        await #expect(throws: GramwiseAPIError.unreachable) {
            try await client(http).goal(accessToken: "token")
        }
    }

    @Test func beingOfflineStaysAURLError() async throws {
        let http = MockHTTPClient(error: URLError(.notConnectedToInternet))

        await #expect(throws: URLError.self) {
            try await client(http).goal(accessToken: "token")
        }
    }

    @Test func malformedBodyIsADecodingError() async throws {
        let http = MockHTTPClient(data: Data("{}".utf8))

        await #expect(throws: APIError.decoding) {
            try await client(http).refresh(refreshToken: "r")
        }
    }

    @Test func signInRefusalsMapByCodeWhateverTheStatus() async throws {
        // The backend answers 400 since it follows RFC 6749 §5.2. Older backends answered 401.
        for status in [400, 401] {
            let wrongPassword = MockHTTPClient(data: envelope("invalid_credentials"), statusCode: status)
            let usedToken = MockHTTPClient(data: envelope("invalid_token"), statusCode: status)

            await #expect(throws: GramwiseAPIError.invalidCredentials) {
                try await client(wrongPassword).signIn(email: "ada@example.com", password: "wrong")
            }
            await #expect(throws: GramwiseAPIError.invalidToken) {
                try await client(usedToken).refresh(refreshToken: "r")
            }
        }
    }

    @Test func signOutPostsTheRefreshToken() async throws {
        let http = MockHTTPClient(data: Data(), statusCode: 204)

        try await client(http).signOut(refreshToken: "r")

        #expect(http.requests.first?.httpMethod == "POST")
        #expect(http.requests.first?.url?.path() == "/auth/logout")
    }

    /// An error response body with `code`, as the backend sends it.
    private func envelope(_ code: String) -> Data {
        Data(#"{"error": {"code": "\#(code)", "message": "Refused", "details": null}}"#.utf8)
    }

    @Test func deleteAccountSendsDelete() async throws {
        let http = MockHTTPClient(data: Data(), statusCode: 204)

        try await client(http).deleteAccount(accessToken: "token")

        #expect(http.requests.first?.httpMethod == "DELETE")
        #expect(http.requests.first?.url?.path() == "/me")
    }

    @Test(arguments: [
        ("2026-10-29T08:15:00Z", 0.0),
        ("2026-10-29T08:15:00.250Z", 0.25),
        ("2026-10-29T08:15:00.250000Z", 0.25),
        ("2026-10-29T09:15:00.5+01:00", 0.5),
    ])
    func parsesServerDates(text: String, fraction: Double) throws {
        let whole = try Date("2026-10-29T08:15:00Z", strategy: .iso8601)

        let parsed = try #require(GramwiseJSON.parseDate(text))

        expectApproximately(parsed.timeIntervalSince(whole), fraction, tolerance: 1e-6)
    }
}
