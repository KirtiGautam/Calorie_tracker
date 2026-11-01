/// The body of a token refresh request.
nonisolated struct GramwiseRefreshRequest: Encodable, Sendable {
    /// The refresh token to exchange.
    let refreshToken: String

    private enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}
