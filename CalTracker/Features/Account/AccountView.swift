import SwiftUI

/// The account sheet: a sign-up and sign-in form while signed out, and sync details with account actions while signed in.
struct AccountView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AccountViewModel

    /// Creates the sheet for `viewModel`.
    init(viewModel: AccountViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let email = viewModel.signedInEmail {
                    AccountSignedInSections(
                        email: email,
                        viewModel: viewModel,
                        onSignOut: signOut,
                        onDeleteAccount: deleteAccount
                    )
                } else {
                    AccountSignedOutForm(viewModel: viewModel, onSubmit: submit)
                }
            }
            .navigationTitle(.accountTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(.doneAction, systemImage: "checkmark", action: close)
                }
            }
            .disabled(viewModel.isWorking)
        }
    }

    // Account requests run in their own tasks rather than the view's, so closing the sheet doesn't abandon a sign-up,
    // sign-out or deletion the server may already have carried out.

    private func submit() {
        Task {
            await viewModel.submit()
        }
    }

    private func signOut() {
        Task {
            await viewModel.signOut()
        }
    }

    private func deleteAccount() {
        Task {
            await viewModel.deleteAccount()
        }
    }

    private func close() {
        dismiss()
    }
}

#Preview {
    AccountView(viewModel: AppDependencies.preview.makeAccountViewModel())
}
