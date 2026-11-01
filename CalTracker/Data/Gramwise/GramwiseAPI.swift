/// The Gramwise backend's accounts and sync routes, so tests can substitute an in-memory server.
nonisolated protocol GramwiseAPI: Sendable {
    /// Creates an account and returns its tokens.
    func signUp(email: String, password: String) async throws -> GramwiseTokenPair

    /// Signs in to an existing account and returns its tokens.
    func signIn(email: String, password: String) async throws -> GramwiseTokenPair

    /// Exchanges a refresh token for a new pair.
    func refresh(refreshToken: String) async throws -> GramwiseTokenPair

    /// Deletes the account with its goal and logs.
    func deleteAccount(accessToken: String) async throws

    /// Returns the stored goal, or `nil` when none has been saved.
    func goal(accessToken: String) async throws -> GramwiseGoal?

    /// Saves `goal` as the goal from its day on, and returns the stored goal.
    ///
    /// - Throws: `GramwiseAPIError.goalOutdated` when the stored goal is from a later day, or saved later the same day.
    func putGoal(_ goal: GramwiseGoal, accessToken: String) async throws -> GramwiseGoal

    /// Applies `changes` and returns the days they touched.
    func pushChanges(_ changes: GramwiseLogChanges, accessToken: String) async throws -> [GramwiseDailyLog]

    /// Returns the days changed after `cursor`, or from the beginning when it's `nil`.
    func dailyLogs(after cursor: String?, accessToken: String) async throws -> GramwiseDailyLogPage
}
