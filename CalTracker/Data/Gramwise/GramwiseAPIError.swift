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

    /// The goal's day isn't its save time's day in any time zone, usually because the device clock is far off.
    case invalidGoalDate

    /// A day would hold more foods than the server allows, counting every device's foods.
    case tooManyFoods

    /// The server doesn't accept the cursor a pull sent.
    case invalidCursor

    /// The backend couldn't be reached at all.
    case unreachable

    /// The server answered with another failure status.
    case server(status: Int)

    /// Whether the server answered and refused what was sent, so sending it again unchanged fails the same way.
    ///
    /// The device is online and signed in, so other requests can still succeed.
    var isRefusal: Bool {
        switch self {
        case .invalidInput, .goalOutdated, .invalidGoalDate, .tooManyFoods, .invalidCursor:
            true
        case .server(let status):
            // Timeouts and rate limits are worth retrying later.
            (400..<500).contains(status) && status != 408 && status != 429
        case .emailTaken, .invalidCredentials, .invalidToken, .sessionExpired, .unreachable:
            false
        }
    }
}
