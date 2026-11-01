/// The body of a sign-up or sign-in request.
nonisolated struct GramwiseCredentials: Encodable, Sendable {
    /// The account email.
    let email: String

    /// The password, sent only over the request and never stored.
    let password: String
}
