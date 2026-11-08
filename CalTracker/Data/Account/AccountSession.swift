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

    /// Whether the tokens are known: read by `restore()`, or set by a sign-in or sign-out since launch.
    @ObservationIgnored private var hasRestored = false

    /// Counts changes to the tokens, so a store call that finishes after a newer change doesn't undo it.
    @ObservationIgnored private var generation = 0

    /// Creates a session that talks to `api` and keeps its tokens in `tokenStore`.
    ///
    /// It looks signed out until `restore()` reads the tokens a previous launch kept.
    init(api: any GramwiseAPI, tokenStore: any TokenStoring) {
        self.api = api
        self.tokenStore = tokenStore
    }

    /// Reads the tokens a previous launch kept, unless they're already known.
    ///
    /// When the store can't be read yet, for example before the first unlock after a restart, the session stays
    /// signed out and the next call tries again.
    func restore() async {
        guard hasRestored == false else { return }
        let started = generation
        let saved: GramwiseTokenPair?
        do {
            saved = try await tokenStore.load()
        } catch {
            return
        }
        // A sign-in, sign-out or another restore that finished during the read wins.
        guard hasRestored == false, generation == started else { return }
        set(saved)
    }

    /// Whether an account is signed in.
    var isSignedIn: Bool {
        user != nil
    }

    /// Creates an account and signs in to it.
    func signUp(email: String, password: String) async throws {
        try await keep(try await api.signUp(email: email, password: password))
    }

    /// Signs in to an existing account.
    func signIn(email: String, password: String) async throws {
        try await keep(try await api.signIn(email: email, password: password))
    }

    /// Forgets the tokens, then asks the server to revoke the refresh token. The log stays on the device.
    ///
    /// When the store can't remove the tokens, the session stays signed in, so the next launch doesn't sign back in.
    /// The device is signed out before the server is asked, and a failed revocation, for example when offline, is
    /// ignored: the refresh token then lasts until it expires, as it did before the server could revoke it.
    func signOut() async throws {
        guard let refreshToken = try await forgetTokens()?.refreshToken else { return }
        try? await api.signOut(refreshToken: refreshToken)
    }

    /// Signs out on this device only and returns the tokens it forgot, if any.
    private func forgetTokens() async throws -> GramwiseTokenPair? {
        let previous = tokens
        set(nil)
        let signedOut = generation
        do {
            try await tokenStore.clear()
        } catch {
            if generation == signedOut {
                set(previous)
            }
            throw error
        }
        return previous
    }

    /// Deletes the account and everything stored with it on the server, then signs out.
    func deleteAccount() async throws {
        try await withAccessToken { [api] accessToken in
            try await api.deleteAccount(accessToken: accessToken)
        }
        // Deleting the account already invalidated its tokens, so there's nothing to revoke.
        _ = try await forgetTokens()
    }

    /// Runs `operation` with the current access token, refreshing the tokens once if the server rejects it.
    ///
    /// Restores the saved tokens first when `restore()` hasn't read them yet.
    ///
    /// - Throws: `GramwiseAPIError.sessionExpired`, after signing out, when there are no tokens or they can't be
    ///   renewed. Otherwise the operation's or the refresh's own error.
    func withAccessToken<Value>(_ operation: (String) async throws -> Value) async throws -> Value {
        await restore()
        guard let current = tokens else { throw GramwiseAPIError.sessionExpired }
        do {
            return try await operation(current.accessToken)
        } catch GramwiseAPIError.invalidToken {
            let renewed = try await renew(current)
            do {
                return try await operation(renewed.accessToken)
            } catch GramwiseAPIError.invalidToken {
                await endExpiredSession()
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
            await endExpiredSession()
            throw GramwiseAPIError.sessionExpired
        }
        // The person may have signed out, or into another account, while the refresh was in flight.
        guard tokens?.user.id == renewed.user.id else { throw GramwiseAPIError.sessionExpired }
        try await keep(renewed)
        return renewed
    }

    /// Signs in with `pair` and saves it. When the store can't save it, the session goes back to how it was.
    private func keep(_ pair: GramwiseTokenPair) async throws {
        let previous = tokens
        set(pair)
        let signedIn = generation
        do {
            try await tokenStore.save(pair)
        } catch {
            if generation == signedIn {
                set(previous)
            }
            throw error
        }
    }

    /// Signs out after the server refused the tokens.
    private func endExpiredSession() async {
        set(nil)
        // The tokens are useless now. If the Keychain can't delete them, the next launch
        // refuses them again and lands here once more, so there's nothing better to do.
        try? await tokenStore.clear()
    }

    /// Makes `pair` the session's tokens before the store call that saves or removes them, so a request that
    /// finishes during that call sees the change.
    private func set(_ pair: GramwiseTokenPair?) {
        generation += 1
        hasRestored = true
        tokens = pair
        user = pair?.user
    }
}
