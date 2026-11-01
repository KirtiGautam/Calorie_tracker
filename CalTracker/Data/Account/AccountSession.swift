import Foundation
import Observation

/// The signed-in Gramwise account on this device, and the only owner of its tokens.
@Observable
final class AccountSession {
    /// The signed-in account, or `nil` when signed out.
    private(set) var user: GramwiseUser?

    @ObservationIgnored private var tokens: GramwiseTokenPair?
    @ObservationIgnored private let api: any GramwiseAPI
    @ObservationIgnored private let tokenStore: any TokenStoring

    /// Creates a session that talks to `api` and restores any tokens `tokenStore` kept.
    init(api: any GramwiseAPI, tokenStore: any TokenStoring) {
        self.api = api
        self.tokenStore = tokenStore
        tokens = tokenStore.load()
        user = tokens?.user
    }

    /// Whether an account is signed in.
    var isSignedIn: Bool {
        user != nil
    }

    /// Creates an account and signs in to it.
    func signUp(email: String, password: String) async throws {
        try keep(try await api.signUp(email: email, password: password))
    }

    /// Signs in to an existing account.
    func signIn(email: String, password: String) async throws {
        try keep(try await api.signIn(email: email, password: password))
    }

    /// Forgets the tokens. The log stays on the device.
    func signOut() throws {
        try tokenStore.clear()
        tokens = nil
        user = nil
    }

    /// Deletes the account and everything stored with it on the server, then signs out.
    func deleteAccount() async throws {
        try await withAccessToken { [api] accessToken in
            try await api.deleteAccount(accessToken: accessToken)
        }
        try signOut()
    }

    /// Runs `operation` with the current access token, refreshing the tokens once if the server rejects it.
    ///
    /// - Throws: `GramwiseAPIError.sessionExpired`, after signing out, when there are no tokens or they can't be
    ///   renewed. Otherwise the operation's or the refresh's own error.
    func withAccessToken<Value>(_ operation: (String) async throws -> Value) async throws -> Value {
        guard let current = tokens else { throw GramwiseAPIError.sessionExpired }
        do {
            return try await operation(current.accessToken)
        } catch GramwiseAPIError.invalidToken {
            let renewed = try await renew(current)
            do {
                return try await operation(renewed.accessToken)
            } catch GramwiseAPIError.invalidToken {
                endExpiredSession()
                throw GramwiseAPIError.sessionExpired
            }
        }
    }

    /// Exchanges `current`'s refresh token for a new pair and keeps it.
    private func renew(_ current: GramwiseTokenPair) async throws -> GramwiseTokenPair {
        let renewed: GramwiseTokenPair
        do {
            renewed = try await api.refresh(refreshToken: current.refreshToken)
        } catch GramwiseAPIError.invalidToken {
            endExpiredSession()
            throw GramwiseAPIError.sessionExpired
        }
        // The person may have signed out, or into another account, while the refresh was in flight.
        guard tokens?.user.id == renewed.user.id else { throw GramwiseAPIError.sessionExpired }
        try keep(renewed)
        return renewed
    }

    private func keep(_ pair: GramwiseTokenPair) throws {
        try tokenStore.save(pair)
        tokens = pair
        user = pair.user
    }

    /// Signs out after the server refused the tokens.
    private func endExpiredSession() {
        // The tokens are useless now. If the Keychain can't delete them, the next launch
        // refuses them again and lands here once more, so there's nothing better to do.
        try? tokenStore.clear()
        tokens = nil
        user = nil
    }
}
