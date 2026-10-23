import SwiftUI

/// A small capsule showing whether the person is cutting, maintaining or bulking.
struct GoalBadge: View {
    let goal: WeightGoal

    /// Capsule insets that grow with Dynamic Type so the badge never clips its text.
    @ScaledMetric(relativeTo: .caption) private var horizontalInset = 8.0
    @ScaledMetric(relativeTo: .caption) private var verticalInset = 4.0

    var body: some View {
        // A tight HStack rather than Label, whose icon column leaves a wide gap at caption size.
        HStack(spacing: 4) {
            Image(systemName: goal.systemImage)
            Text(goal.shortTitle)
        }
        .font(.caption)
        .bold()
        .foregroundStyle(.secondary)
        .padding(.horizontal, horizontalInset)
        .padding(.vertical, verticalInset)
        .background(.fill.tertiary, in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(.goalBadgeAccessibilityLabel(String(localized: goal.shortTitle))))
    }
}

#Preview {
    VStack {
        ForEach(WeightGoal.allCases) { goal in
            GoalBadge(goal: goal)
        }
    }
}
