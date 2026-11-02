import SwiftUI

/// The last account action's error, shown inline in the account form. Nothing shows when there's no error.
struct AccountErrorSection: View {
    /// The message to show, or `nil` for none.
    let message: LocalizedStringResource?

    var body: some View {
        if let message {
            Section {
                Label {
                    Text(message)
                } icon: {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

#Preview {
    Form {
        AccountErrorSection(message: .errorInvalidCredentials)
    }
}
