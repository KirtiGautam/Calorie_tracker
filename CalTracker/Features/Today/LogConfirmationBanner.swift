import SwiftUI

/// A short-lived capsule confirming what was just logged.
struct LogConfirmationBanner: View {
    let loggedFood: LoggedFood

    var body: some View {
        Label {
            Text(loggedFood.message)
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(in: .capsule)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("logConfirmation")
    }
}

#Preview {
    LogConfirmationBanner(loggedFood: LoggedFood(name: "Bananas, raw", grams: 150))
}
