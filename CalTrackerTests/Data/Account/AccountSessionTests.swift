import Foundation
import Testing
@testable import CalTracker

@Suite(.tags(.networking))
struct AccountSessionTests {
    private let configuration = GramwiseConfiguration(baseURL: URL(string: "https://api.example.com") ?? URL(filePath: "/"))
    private let oldTokens = GramwiseTokenPair(
        accessToken: "old-access",
        refreshToken: "old-refresh",
        user: GramwiseUser(id: UUID(uuidString: "148a1950-9ea0-4a7c-af35-126a8707de58") ?? UUID(), email: "ada@example.com")
    )

    private func session(_ http: MockHTTPClient, store: InMemoryTokenStore) -> AccountSession {
        AccountSession(api: GramwiseClient(httpClient: http, configuration: configuration), tokenStore: store)
    }

    @Test func restoresSavedTokens() {
        let store = InMemoryTokenStore(tokens: oldTokens)

        let account = session(MockHTTPClient(data: Data()), store: store)

        #expect(account.user == oldTokens.user)
        #expect(account.isSignedIn)
    }

    @Test func signUpSavesTokens() async throws {
        let store = InMemoryTokenStore()
        let account = session(MockHTTPClient(data: try FixtureLoader.data(named: "gramwise_tokens"), statusCode: 201), store: store)

        try await account.signUp(email: "ada@example.com", password: "correct horse")

        #expect(account.user?.email == "ada@example.com")
        #expect(store.tokens?.accessToken == "test-access-token")
    }

    @Test func refreshesAndRetriesOnce() async throws {
        let store = InMemoryTokenStore(tokens: oldTokens)
        let http = MockHTTPClient(sequence: [
            .success((MockHTTPClient.envelope(code: "invalid_token"), 401)),
            .success((try FixtureLoader.data(named: "gramwise_tokens"), 200)),
            .success((MockHTTPClient.envelope(code: "goal_not_found"), 404)),
        ])
        let account = session(http, store: store)
        let api = GramwiseClient(httpClient: http, configuration: configuration)

        let goal = try await account.withAccessToken { try await api.goal(accessToken: $0) }

        #expect(goal == nil)
        #expect(http.requests.map { $0.url?.path() } == ["/me/goal", "/auth/refresh", "/me/goal"])
        #expect(http.requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer old-access")
        #expect(http.requests[2].value(forHTTPHeaderField: "Authorization") == "Bearer test-access-token")
        let refreshBody = try #require(http.requests[1].httpBody)
        #expect(String(decoding: refreshBody, as: UTF8.self).contains("old-refresh"))
        #expect(store.tokens?.refreshToken == "test-refresh-token")
        #expect(account.isSignedIn)
    }

    @Test func aRejectedRefreshSignsOut() async throws {
        let store = InMemoryTokenStore(tokens: oldTokens)
        let http = MockHTTPClient(data: MockHTTPClient.envelope(code: "invalid_token"), statusCode: 401)
        let account = session(http, store: store)
        let api = GramwiseClient(httpClient: http, configuration: configuration)

        await #expect(throws: GramwiseAPIError.sessionExpired) {
            try await account.withAccessToken { try await api.goal(accessToken: $0) }
        }

        #expect(account.isSignedIn == false)
        #expect(store.tokens == nil)
        #expect(http.requests.count == 2)
    }

    @Test func aRejectionAfterRefreshSignsOut() async throws {
        let store = InMemoryTokenStore(tokens: oldTokens)
        let http = MockHTTPClient(sequence: [
            .success((MockHTTPClient.envelope(code: "invalid_token"), 401)),
            .success((try FixtureLoader.data(named: "gramwise_tokens"), 200)),
            .success((MockHTTPClient.envelope(code: "invalid_token"), 401)),
        ])
        let account = session(http, store: store)
        let api = GramwiseClient(httpClient: http, configuration: configuration)

        await #expect(throws: GramwiseAPIError.sessionExpired) {
            try await account.withAccessToken { try await api.goal(accessToken: $0) }
        }

        #expect(account.isSignedIn == false)
        #expect(http.requests.count == 3)
    }

    @Test func goingOfflineDuringRefreshKeepsTheSession() async throws {
        let store = InMemoryTokenStore(tokens: oldTokens)
        let http = MockHTTPClient(sequence: [
            .success((MockHTTPClient.envelope(code: "invalid_token"), 401)),
            .failure(URLError(.notConnectedToInternet)),
        ])
        let account = session(http, store: store)
        let api = GramwiseClient(httpClient: http, configuration: configuration)

        await #expect(throws: URLError.self) {
            try await account.withAccessToken { try await api.goal(accessToken: $0) }
        }

        #expect(account.isSignedIn)
        #expect(store.tokens == oldTokens)
    }

    @Test func withoutTokensTheSessionHasExpired() async {
        let account = session(MockHTTPClient(data: Data()), store: InMemoryTokenStore())

        await #expect(throws: GramwiseAPIError.sessionExpired) {
            try await account.withAccessToken { _ in () }
        }
    }

    @Test func signOutClearsTokens() throws {
        let store = InMemoryTokenStore(tokens: oldTokens)
        let account = session(MockHTTPClient(data: Data()), store: store)

        try account.signOut()

        #expect(account.user == nil)
        #expect(store.tokens == nil)
    }

    @Test func deleteAccountSignsOut() async throws {
        let store = InMemoryTokenStore(tokens: oldTokens)
        let http = MockHTTPClient(data: Data(), statusCode: 204)
        let account = session(http, store: store)

        try await account.deleteAccount()

        #expect(http.requests.first?.httpMethod == "DELETE")
        #expect(account.isSignedIn == false)
        #expect(store.tokens == nil)
    }
}
