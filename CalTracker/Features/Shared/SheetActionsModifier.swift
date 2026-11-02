import SwiftUI

/// Adds a sheet's Cancel button, which dismisses the sheet, and the button that confirms it.
struct SheetActionsModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    /// The confirming button's title, such as "Save".
    let confirmTitle: LocalizedStringResource

    /// Whether the confirming button is disabled.
    let isConfirmDisabled: Bool

    /// Runs when the person confirms. It's responsible for dismissing the sheet once it succeeds.
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(.cancelAction, systemImage: "xmark", role: .cancel, action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmTitle, systemImage: "checkmark", action: onConfirm)
                        .disabled(isConfirmDisabled)
                }
            }
    }

    private func cancel() {
        dismiss()
    }
}

extension View {
    /// Adds a sheet's Cancel button and a confirming button titled `confirmTitle` that runs `action`.
    func sheetActions(
        confirm confirmTitle: LocalizedStringResource,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        modifier(SheetActionsModifier(confirmTitle: confirmTitle, isConfirmDisabled: isDisabled, onConfirm: action))
    }
}
