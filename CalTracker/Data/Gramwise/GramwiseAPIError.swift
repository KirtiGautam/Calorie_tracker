/// Failures the Gramwise backend reports, decoded from its error envelope.
nonisolated enum GramwiseAPIError: Error, Equatable, Sendable {
    /// Sign-up used an email that already has an account.
    case emailTaken

    /// Sign-in used a wrong password or an unknown email.
    case invalidCredentials

    /// The access or refresh token is missing, expired or no longer valid.
    case invalidToken

    /// The session couldn't be renewed, so the device was signed out.
    case sessionExpired

    /// The server rejected the request's content, such as a malformed email.
    case invalidInput

    /// A newer goal is already saved, and the goals of past days can't change.
    case goalOutdated

    /// The backend couldn't be reached at all.
    case unreachable

    /// The server answered with another failure status.
    case server(status: Int)
}
