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

    private func session(_ http: MockHTTPClient, store: any TokenStoring) -> AccountSession {
        AccountSession(api: GramwiseClient(httpClient: http, configuration: configuration), tokenStore: store)
    }

    /// A session that has already restored `store`'s tokens.
    private func restoredSession(_ http: MockHTTPClient, store: any TokenStoring) async -> AccountSession {
        let account = session(http, store: store)
        await account.restore()
        return account
    }

    @Test func restoresSavedTokens() async {
        let account = session(MockHTTPClient(data: Data()), store: InMemoryTokenStore(tokens: oldTokens))
        #expect(account.isSignedIn == false)

        await account.restore()

        #expect(account.user == oldTokens.user)
        #expect(account.isSignedIn)
    }

    @Test func usingTheTokensRestoresThemFirst() async throws {
        let account = session(MockHTTPClient(data: Data()), store: InMemoryTokenStore(tokens: oldTokens))

        let accessToken = try await account.withAccessToken { $0 }

        #expect(accessToken == "old-access")
        #expect(account.isSignedIn)
    }

    @Test func restoreTriesAgainAfterAFailedRead() async {
        let store = FaultyTokenStore(tokens: oldTokens)
        store.loadError = KeychainError(status: errSecInteractionNotAllowed)
        let account = session(MockHTTPClient(data: Data()), store: store)

        await account.restore()
        #expect(account.isSignedIn == false)
        store.loadError = nil
        await account.restore()

        #expect(account.user == oldTokens.user)
    }

    @Test func restoreDoesNotReplaceASignInSinceLaunch() async throws {
        let store = InMemoryTokenStore()
        let account = session(MockHTTPClient(data: try FixtureLoader.data(named: "gramwise_tokens")), store: store)
        let otherTokens = GramwiseTokenPair(
            accessToken: "other-access",
            refreshToken: "other-refresh",
            user: GramwiseUser(id: UUID(), email: "grace@example.com")
        )

        try await account.signIn(email: "ada@example.com", password: "correct horse")
        try await store.save(otherTokens)
        await account.restore()

        #expect(account.user?.email == "ada@example.com")
    }

    @Test func aFailedSaveLeavesTheSessionSignedOut() async throws {
        let store = FaultyTokenStore()
        store.writeError = KeychainError(status: errSecNotAvailable)
        let account = session(MockHTTPClient(data: try FixtureLoader.data(named: "gramwise_tokens"), statusCode: 201), store: store)

        await #expect(throws: KeychainError(status: errSecNotAvailable)) {
            try await account.signUp(email: "ada@example.com", password: "correct horse")
        }

        #expect(account.isSignedIn == false)
        #expect(store.tokens == nil)
    }

    @Test func aFailedSignOutStaysSignedIn() async {
        let store = FaultyTokenStore(tokens: oldTokens)
        let account = await restoredSession(MockHTTPClient(data: Data()), store: store)
        store.writeError = KeychainError(status: errSecNotAvailable)

        await #expect(throws: KeychainError(status: errSecNotAvailable)) {
            try await account.signOut()
        }

        #expect(account.user == oldTokens.user)
        #expect(store.tokens == oldTokens)
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
        let account = await restoredSession(http, store: store)
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
        let account = await restoredSession(http, store: store)
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
        let account = await restoredSession(http, store: store)
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
        let account = await restoredSession(http, store: store)
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

    @Test func signOutClearsTokens() async throws {
        let store = InMemoryTokenStore(tokens: oldTokens)
        let account = await restoredSession(MockHTTPClient(data: Data()), store: store)

        try await account.signOut()

        #expect(account.user == nil)
        #expect(store.tokens == nil)
    }

    @Test func signOutRevokesTheRefreshTokenOnTheServer() async throws {
        let store = InMemoryTokenStore(tokens: oldTokens)
        let http = MockHTTPClient(data: Data(), statusCode: 204)
        let account = await restoredSession(http, store: store)

        try await account.signOut()

        let request = try #require(http.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path() == "/auth/logout")
        let body = try JSONSerialization.jsonObject(with: try #require(request.httpBody)) as? [String: String]
        #expect(body == ["refresh_token": "old-refresh"])
        #expect(request.timeoutInterval == GramwiseClient.signOutTimeout)
    }

    @Test func signOutOfflineStillSignsOut() async throws {
        let store = InMemoryTokenStore(tokens: oldTokens)
        let account = await restoredSession(MockHTTPClient(error: URLError(.notConnectedToInternet)), store: store)

        try await account.signOut()

        #expect(account.user == nil)
        #expect(store.tokens == nil)
    }

    @Test func aFailedSignOutDoesNotRevokeTheTokens() async {
        let store = FaultyTokenStore(tokens: oldTokens)
        let http = MockHTTPClient(data: Data(), statusCode: 204)
        let account = await restoredSession(http, store: store)
        store.writeError = KeychainError(status: errSecNotAvailable)

        _ = try? await account.signOut()

        #expect(http.requests.isEmpty)
    }

    @Test func deleteAccountSignsOut() async throws {
        let store = InMemoryTokenStore(tokens: oldTokens)
        let http = MockHTTPClient(data: Data(), statusCode: 204)
        let account = await restoredSession(http, store: store)

        try await account.deleteAccount()

        // Deleting the account invalidated its tokens, so sign-out doesn't ask to revoke them.
        #expect(http.requests.map(\.httpMethod) == ["DELETE"])
        #expect(account.isSignedIn == false)
        #expect(store.tokens == nil)
    }
}
