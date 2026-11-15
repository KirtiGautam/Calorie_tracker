import SwiftUI

/// A short-lived capsule confirming what was just logged, with Undo when the log offers it.
struct LogConfirmationBanner: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// What was just logged.
    let loggedFood: LoggedFood

    /// Called when the person taps Undo, which only shows when `loggedFood` has an undoable entry.
    var onUndo: () -> Void = {}

    var body: some View {
        // Stack at accessibility sizes so a long food name never squeezes Undo out.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))

        layout {
            Label {
                Text(loggedFood.message)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("logConfirmation")

            if loggedFood.undoableEntry != nil {
                Button(.undoAction, systemImage: "arrow.uturn.backward", action: onUndo)
                    .labelStyle(.titleOnly)
                    .bold()
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                    .accessibilityIdentifier("undoLog")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(in: .capsule)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

#Preview {
    VStack {
        LogConfirmationBanner(loggedFood: LoggedFood(name: "Bananas, raw", grams: 150))
        LogConfirmationBanner(
            loggedFood: LoggedFood(
                name: "Bananas, raw",
                grams: 120,
                undoableEntry: FoodLogEntry(food: .previewBanana, grams: 120, loggedAt: .now)
            )
        )
    }
    .modelContainer(AppModelContainer.preview)
}
