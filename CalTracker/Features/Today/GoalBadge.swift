import SwiftUI

/// A small capsule showing whether the person is cutting, maintaining or bulking.
struct GoalBadge: View {
    /// The goal to show.
    let goal: WeightGoal

    var body: some View {
        // A tight HStack rather than Label, whose icon column leaves a wide gap at caption size.
        HStack(spacing: 4) {
            Image(systemName: goal.systemImage)
            Text(goal.shortTitle)
        }
        .capsuleBadge()
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
