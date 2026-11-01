import Foundation
import Synchronization
@testable import CalTracker

/// An in-memory Gramwise backend with the real server's rules: case-insensitive emails, goals that only move forward,
/// per-day merges by entry ID that keep emptied days and hold at most 200 foods, and keyset-style pages of changed
/// days that refuse cursors the server didn't hand out.
nonisolated final class FakeGramwiseAPI: GramwiseAPI {
    /// One stored day.
    struct Day {
        var foods: [GramwiseLoggedFood]
        var sequence: Int
    }

    private struct Account {
        let user: GramwiseUser
        let password: String
    }

    private struct State {
        var accounts: [String: Account] = [:]
        var accessTokens: [String: UUID] = [:]
        var refreshTokens: [String: UUID] = [:]
        var goals: [UUID: GramwiseGoal] = [:]
        var days: [UUID: [String: Day]] = [:]
        var sequence = 0
        var calls: [String] = []
        var failure: (any Error)?
        var refusals: [String: GramwiseAPIError] = [:]
        var losesNextPushResponse = false
    }

    /// How many days `dailyLogs(after:accessToken:)` returns per page.
    let pageSize: Int

    private let state = Mutex(State())
    private let pushHook = Mutex<(@MainActor @Sendable () -> Void)?>(nil)

    /// Creates an empty server that pages `pageSize` days at a time.
    init(pageSize: Int = 100) {
        self.pageSize = pageSize
    }

    // MARK: - Test controls

    /// Makes every call throw `error` until it's set back to `nil`.
    func fail(with error: (any Error)?) {
        state.withLock { $0.failure = error }
    }

    /// Makes every `call`, such as `pushChanges`, throw `error` until it's set back to `nil`. Other calls still work.
    func refuse(_ call: String, with error: GramwiseAPIError?) {
        state.withLock { $0.refusals[call] = error }
    }

    /// Stores the next push, then throws a timeout instead of answering, as if the response had been lost.
    func loseNextPushResponse() {
        state.withLock { $0.losesNextPushResponse = true }
    }

    /// Runs `action` on the main actor during every push, after it's stored, so tests can act while it's in flight.
    func onPush(_ action: @escaping @MainActor @Sendable () -> Void) {
        pushHook.withLock { $0 = action }
    }

    /// Invalidates every access token, as if they had expired. Refresh tokens keep working.
    func expireAccessTokens() {
        state.withLock { $0.accessTokens.removeAll() }
    }

    /// Invalidates every token, as if the secret had been rotated.
    func revokeAllTokens() {
        state.withLock { state in
            state.accessTokens.removeAll()
            state.refreshTokens.removeAll()
        }
    }

    /// The names of the calls received so far, such as `pushChanges` or `putGoal`.
    var calls: [String] {
        state.withLock { $0.calls }
    }

    /// The foods stored for `user` on `day`, or `nil` when the day doesn't exist.
    func foods(for user: GramwiseUser, on day: String) -> [GramwiseLoggedFood]? {
        state.withLock { $0.days[user.id]?[day]?.foods }
    }

    /// Every day stored for `user`.
    func dayKeys(for user: GramwiseUser) -> Set<String> {
        state.withLock { Set(($0.days[user.id] ?? [:]).keys) }
    }

    /// The goal stored for `user`.
    func storedGoal(for user: GramwiseUser) -> GramwiseGoal? {
        state.withLock { $0.goals[user.id] }
    }

    /// Stores `goal` for `user` directly, as if another device had saved it.
    func setGoal(_ goal: GramwiseGoal, for user: GramwiseUser) {
        state.withLock { $0.goals[user.id] = goal }
    }

    /// Deletes `user`'s goal directly, as if the server's data had been reset.
    func removeGoal(for user: GramwiseUser) {
        state.withLock { $0.goals[user.id] = nil }
    }

    /// Whether an account exists for `email`.
    func hasAccount(email: String) -> Bool {
        state.withLock { $0.accounts[Self.normalized(email)] != nil }
    }

    // MARK: - GramwiseAPI

    func signUp(email: String, password: String) async throws -> GramwiseTokenPair {
        try state.withLock { state in
            try Self.begin("signUp", in: &state)
            let key = Self.normalized(email)
            guard state.accounts[key] == nil else { throw GramwiseAPIError.emailTaken }
            let user = GramwiseUser(id: UUID(), email: key)
            state.accounts[key] = Account(user: user, password: password)
            return Self.issueTokens(for: user, in: &state)
        }
    }

    func signIn(email: String, password: String) async throws -> GramwiseTokenPair {
        try state.withLock { state in
            try Self.begin("signIn", in: &state)
            guard let account = state.accounts[Self.normalized(email)], account.password == password else {
                throw GramwiseAPIError.invalidCredentials
            }
            return Self.issueTokens(for: account.user, in: &state)
        }
    }

    func refresh(refreshToken: String) async throws -> GramwiseTokenPair {
        try state.withLock { state in
            try Self.begin("refresh", in: &state)
            guard let userID = state.refreshTokens[refreshToken],
                  let account = state.accounts.values.first(where: { $0.user.id == userID })
            else {
                throw GramwiseAPIError.invalidToken
            }
            return Self.issueTokens(for: account.user, in: &state)
        }
    }

    func deleteAccount(accessToken: String) async throws {
        try state.withLock { state in
            let userID = try Self.authorize("deleteAccount", accessToken, in: &state)
            state.accounts = state.accounts.filter { $0.value.user.id != userID }
            state.goals[userID] = nil
            state.days[userID] = nil
            state.accessTokens = state.accessTokens.filter { $0.value != userID }
            state.refreshTokens = state.refreshTokens.filter { $0.value != userID }
        }
    }

    func goal(accessToken: String) async throws -> GramwiseGoal? {
        try state.withLock { state in
            let userID = try Self.authorize("goal", accessToken, in: &state)
            return state.goals[userID]
        }
    }

    func putGoal(_ goal: GramwiseGoal, accessToken: String) async throws -> GramwiseGoal {
        try state.withLock { state in
            let userID = try Self.authorize("putGoal", accessToken, in: &state)
            if let stored = state.goals[userID] {
                // Like the server: a later day or a later save the same day wins, a retry returns the stored goal,
                // and anything older is refused.
                if (goal.effectiveFrom, goal.updatedAt) == (stored.effectiveFrom, stored.updatedAt) {
                    return stored
                }
                guard (goal.effectiveFrom, goal.updatedAt) > (stored.effectiveFrom, stored.updatedAt) else {
                    throw GramwiseAPIError.goalOutdated
                }
            }
            state.goals[userID] = goal
            return goal
        }
    }

    func pushChanges(_ changes: GramwiseLogChanges, accessToken: String) async throws -> [GramwiseDailyLog] {
        let touched = try storeChanges(changes, accessToken: accessToken)
        if let action = pushHook.withLock({ $0 }) {
            await action()
        }
        let losesResponse = state.withLock { state in
            defer { state.losesNextPushResponse = false }
            return state.losesNextPushResponse
        }
        if losesResponse {
            throw URLError(.timedOut)
        }
        return touched
    }

    private func storeChanges(_ changes: GramwiseLogChanges, accessToken: String) throws -> [GramwiseDailyLog] {
        try state.withLock { state in
            let userID = try Self.authorize("pushChanges", accessToken, in: &state)
            let touched = Set(changes.added.map(\.logDate)).union(changes.removed.map(\.logDate))
            state.sequence += 1
            var days = state.days[userID] ?? [:]
            for dayKey in touched {
                var byID: [UUID: GramwiseLoggedFood] = [:]
                for food in days[dayKey]?.foods ?? [] {
                    byID[food.entryID] = food
                }
                for added in changes.added where added.logDate == dayKey {
                    byID[added.food.entryID] = added.food
                }
                for removed in changes.removed where removed.logDate == dayKey {
                    byID[removed.entryID] = nil
                }
                // Like the server, a day over the limit refuses the whole request.
                guard byID.count <= Self.maxFoodsPerDay else { throw GramwiseAPIError.tooManyFoods }
                days[dayKey] = Day(foods: byID.values.sorted { $0.loggedAt < $1.loggedAt }, sequence: state.sequence)
            }
            state.days[userID] = days
            return touched.sorted().compactMap { key in days[key].map { Self.publicDay(key, $0) } }
        }
    }

    func dailyLogs(after cursor: String?, accessToken: String) async throws -> GramwiseDailyLogPage {
        try state.withLock { state in
            let userID = try Self.authorize("dailyLogs", accessToken, in: &state)
            let position = cursor.flatMap(Self.position(from:))
            if cursor != nil && position == nil {
                throw GramwiseAPIError.invalidCursor
            }
            let changed = (state.days[userID] ?? [:])
                .filter { key, day in position.map { (day.sequence, key) > $0 } ?? true }
                .sorted { ($0.value.sequence, $0.key) < ($1.value.sequence, $1.key) }
            let page = changed.prefix(pageSize)
            let next = page.last.map { "\($0.value.sequence)|\($0.key)" } ?? cursor
            return GramwiseDailyLogPage(
                days: page.map { Self.publicDay($0.key, $0.value) },
                nextCursor: next,
                hasMore: changed.count > pageSize
            )
        }
    }

    // MARK: - Helpers

    /// The most foods the server keeps for one day.
    static let maxFoodsPerDay = 200

    private static func begin(_ call: String, in state: inout State) throws {
        state.calls.append(call)
        if let failure = state.failure {
            throw failure
        }
        if let refusal = state.refusals[call] {
            throw refusal
        }
    }

    private static func authorize(_ call: String, _ accessToken: String, in state: inout State) throws -> UUID {
        try begin(call, in: &state)
        guard let userID = state.accessTokens[accessToken] else { throw GramwiseAPIError.invalidToken }
        return userID
    }

    private static func issueTokens(for user: GramwiseUser, in state: inout State) -> GramwiseTokenPair {
        let pair = GramwiseTokenPair(
            accessToken: "access-\(UUID().uuidString)",
            refreshToken: "refresh-\(UUID().uuidString)",
            user: user
        )
        state.accessTokens[pair.accessToken] = user.id
        state.refreshTokens[pair.refreshToken] = user.id
        return pair
    }

    private static func publicDay(_ key: String, _ day: Day) -> GramwiseDailyLog {
        GramwiseDailyLog(logDate: key, foods: day.foods, updatedAt: Date(timeIntervalSince1970: Double(day.sequence)))
    }

    private static func position(from cursor: String) -> (Int, String)? {
        let parts = cursor.split(separator: "|", maxSplits: 1)
        guard parts.count == 2, let sequence = Int(parts[0]) else { return nil }
        return (sequence, String(parts[1]))
    }

    private static func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
