import SwiftUI

/// The signed-out account form: create an account or sign in with an email and password.
struct AccountSignedOutForm: View {
    /// The form's state.
    @Bindable var viewModel: AccountViewModel

    /// Called when the person submits the form.
    let onSubmit: () -> Void

    var body: some View {
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
                .onSubmit(onSubmit)
        } footer: {
            if viewModel.mode == .createAccount {
                Text(.passwordRequirement(AccountViewModel.minimumPasswordLength))
            }
        }

        AccountErrorSection(message: viewModel.errorMessage)

        Section {
            Button(action: onSubmit) {
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
}

#Preview {
    Form {
        AccountSignedOutForm(viewModel: AppDependencies.preview.makeAccountViewModel(), onSubmit: {})
    }
}
