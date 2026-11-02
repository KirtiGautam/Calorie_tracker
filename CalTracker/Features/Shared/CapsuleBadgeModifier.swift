import SwiftUI

/// Styles a short label as a small capsule, with insets that grow with Dynamic Type so the badge never clips its text.
struct CapsuleBadgeModifier: ViewModifier {
    @ScaledMetric(relativeTo: .caption) private var horizontalInset = 8.0
    @ScaledMetric(relativeTo: .caption) private var verticalInset = 4.0

    func body(content: Content) -> some View {
        content
            .font(.caption)
            .bold()
            .foregroundStyle(.secondary)
            .padding(.horizontal, horizontalInset)
            .padding(.vertical, verticalInset)
            .background(.fill.tertiary, in: .capsule)
    }
}

extension View {
    /// Styles the view as a small capsule badge, such as the source of a food.
    func capsuleBadge() -> some View {
        modifier(CapsuleBadgeModifier())
    }
}
