import Foundation
import Observation

/// Drives the account sheet: the sign-up and sign-in form while signed out, and sync details and account actions while signed in.
@Observable
final class AccountViewModel {
    /// The shortest password the server accepts.
    static let minimumPasswordLength = 8

    /// Whether the form creates an account or signs in.
    var mode: AccountFormMode = .createAccount

    /// The email being typed.
    var email = ""

    /// The password being typed. Cleared after a successful sign-in.
    var password = ""

    /// Whether an account request is in flight.
    private(set) var isWorking = false

    /// The last account action's error, shown inline.
    private(set) var errorMessage: LocalizedStringResource?

    @ObservationIgnored private let account: AccountSession
    @ObservationIgnored private let sync: SyncEngine

    /// Creates a view model for `account`, which asks `sync` to run after sign-in and sign-out.
    init(account: AccountSession, sync: SyncEngine) {
        self.account = account
        self.sync = sync
    }

    /// The signed-in account's email, or `nil` when signed out.
    var signedInEmail: String? {
        account.user?.email
    }

    /// Where sync stands.
    var syncStatus: SyncStatus {
        sync.status
    }

    /// When the last sync finished, or `nil` if none has.
    var lastSyncedAt: Date? {
        sync.lastSyncedAt
    }

    /// Whether the form has an email and password and nothing is in flight.
    var canSubmit: Bool {
        trimmedEmail.isEmpty == false && password.isEmpty == false && isWorking == false
    }

    /// Creates an account or signs in, depending on `mode`, then starts a sync.
    func submit() async {
        guard canSubmit else { return }
        if mode == .createAccount && password.count < Self.minimumPasswordLength {
            errorMessage = .errorPasswordTooShort
            return
        }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            switch mode {
            case .createAccount: try await account.signUp(email: trimmedEmail, password: password)
            case .signIn: try await account.signIn(email: trimmedEmail, password: password)
            }
            password = ""
            sync.requestSync()
        } catch is CancellationError {
            // The sheet closed mid-request. Nothing to report.
        } catch {
            errorMessage = userMessage(for: error)
        }
    }

    /// Starts a sync now.
    func syncNow() {
        sync.requestSync()
    }

    /// Signs out. The log stays on the device.
    func signOut() {
        do {
            try account.signOut()
            errorMessage = nil
            sync.requestSync()
        } catch {
            errorMessage = userMessage(for: error)
        }
    }

    /// Deletes the account and its backup, then signs out. The log stays on the device.
    func deleteAccount() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await account.deleteAccount()
            sync.requestSync()
        } catch is CancellationError {
            // The sheet closed mid-request. Nothing to report.
        } catch {
            errorMessage = userMessage(for: error)
            // A failed delete may have signed out an expired session, so refresh the status.
            sync.requestSync()
        }
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
