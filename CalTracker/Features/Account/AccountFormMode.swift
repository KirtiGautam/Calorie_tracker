import Foundation

/// Whether the signed-out account form creates an account or signs in to one.
enum AccountFormMode: CaseIterable, Identifiable {
    case createAccount
    case signIn

    /// The stable identity of the option.
    var id: Self { self }

    /// The localized name shown in the picker.
    var title: LocalizedStringResource {
        switch self {
        case .createAccount: .accountModeCreate
        case .signIn: .accountModeSignIn
        }
    }

    /// The localized title of the submit button.
    var submitTitle: LocalizedStringResource {
        switch self {
        case .createAccount: .createAccountAction
        case .signIn: .signInAction
        }
    }
}
