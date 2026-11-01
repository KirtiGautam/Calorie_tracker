import SwiftUI

/// The account sheet: a sign-up and sign-in form while signed out, and sync details with account actions while signed in.
struct AccountView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AccountViewModel
    @State private var isConfirmingDeletion = false

    init(viewModel: AccountViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let email = viewModel.signedInEmail {
                    signedInSections(email: email)
                } else {
                    signedOutSections
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
            .confirmationDialog(.deleteAccountConfirmTitle, isPresented: $isConfirmingDeletion, titleVisibility: .visible) {
                Button(.deleteAccountAction, role: .destructive, action: deleteAccount)
            } message: {
                Text(.deleteAccountConfirmMessage)
            }
        }
    }

    // MARK: - Signed out

    @ViewBuilder
    private var signedOutSections: some View {
        Section {
            Picker(.accountModeField, selection: $viewModel.mode) {
                ForEach(AccountFormMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        } footer: {
            Text(.accountSignedOutFooter)
        }

        Section {
            TextField(.emailField, text: $viewModel.email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField(.passwordField, text: $viewModel.password)
                .textContentType(viewModel.mode == .createAccount ? .newPassword : .password)
                .onSubmit(submit)
        } footer: {
            if viewModel.mode == .createAccount {
                Text(.passwordRequirement(AccountViewModel.minimumPasswordLength))
            }
        }

        errorSection

        Section {
            Button(action: submit) {
                Text(viewModel.mode.submitTitle)
                    .frame(maxWidth: .infinity)
                    // An overlay keeps the title centered while the spinner shows.
                    .overlay(alignment: .trailing) {
                        if viewModel.isWorking {
                            ProgressView()
                        }
                    }
            }
            .disabled(viewModel.canSubmit == false)
        }
    }

    // MARK: - Signed in

    @ViewBuilder
    private func signedInSections(email: String) -> some View {
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

        errorSection

        Section {
            Button(.signOutAction, action: signOut)
        } footer: {
            Text(.signOutFooter)
        }

        Section {
            Button(.deleteAccountAction, role: .destructive) {
                isConfirmingDeletion = true
            }
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = viewModel.errorMessage {
            Section {
                Label {
                    Text(errorMessage)
                } icon: {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
    }

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
