/// The body of every Gramwise error response: `{"error": {"code", "message", "details"}}`.
nonisolated struct GramwiseErrorEnvelope: Decodable, Sendable {
    /// The error itself.
    let error: Body

    /// The stable code clients branch on, and a message meant for developers.
    struct Body: Decodable, Sendable {
        /// A stable code such as `email_taken` or `invalid_token`.
        let code: String

        /// A developer-facing description. Never shown to the person.
        let message: String
    }
}
