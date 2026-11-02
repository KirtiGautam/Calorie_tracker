import SwiftUI

extension View {
    /// Shows an alert titled `title` while `message` holds an error message, and clears the message when it's dismissed.
    ///
    /// - Parameters:
    ///   - title: What failed, such as "Couldn't Save Targets".
    ///   - message: The message from `userMessage(for:)`, or `nil` when there's no error to show.
    func errorAlert(_ title: LocalizedStringResource, message: Binding<LocalizedStringResource?>) -> some View {
        alert(title, item: message) { _ in
        } message: { message in
            Text(message)
        }
    }
}
