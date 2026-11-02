import SwiftUI

/// The signed-in account sheet: the account and its sync, then sign-out and account deletion.
struct AccountSignedInSections: View {
    /// The signed-in account's email.
    let email: String

    /// The account and sync state.
    let viewModel: AccountViewModel

    /// Called when the person signs out.
    let onSignOut: () -> Void

    /// Called when the person confirms deleting the account.
    let onDeleteAccount: () -> Void

    @State private var isConfirmingDeletion = false

    var body: some View {
        Section {
            LabeledContent {
                Text(email)
            } label: {
                Text(.emailField)
            }
            LabeledContent {
                if let lastSyncedAt = viewModel.lastSyncedAt {
                    Text(lastSyncedAt, format: .relative(presentation: .named))
                } else {
                    Text(.lastSyncNever)
                }
            } label: {
                Text(.lastSyncLabel)
            }
            if case .failed(let message) = viewModel.syncStatus {
                Label {
                    Text(message)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            Button(action: viewModel.syncNow) {
                HStack {
                    Text(.syncNowAction)
                    if viewModel.syncStatus == .syncing {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(viewModel.syncStatus == .syncing)
        } footer: {
            Text(.syncFooter)
        }

        AccountErrorSection(message: viewModel.errorMessage)

        Section {
            Button(.signOutAction, action: onSignOut)
        } footer: {
            Text(.signOutFooter)
        }

        Section {
            Button(.deleteAccountAction, role: .destructive, action: confirmDeletion)
                .confirmationDialog(.deleteAccountConfirmTitle, isPresented: $isConfirmingDeletion, titleVisibility: .visible) {
                    Button(.deleteAccountAction, role: .destructive, action: onDeleteAccount)
                } message: {
                    Text(.deleteAccountConfirmMessage)
                }
        }
    }

    private func confirmDeletion() {
        isConfirmingDeletion = true
    }
}

#Preview {
    Form {
        AccountSignedInSections(
            email: "kirti@example.com",
            viewModel: AppDependencies.preview.makeAccountViewModel(),
            onSignOut: {},
            onDeleteAccount: {}
        )
    }
}
