/// What sign-up, sign-in and refresh return.
nonisolated struct GramwiseTokenPair: Codable, Hashable, Sendable {
    /// The short-lived token sent as `Authorization: Bearer …`.
    let accessToken: String

    /// The long-lived token exchanged for a new pair when the access token expires.
    let refreshToken: String

    /// The account the tokens belong to.
    let user: GramwiseUser

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}
