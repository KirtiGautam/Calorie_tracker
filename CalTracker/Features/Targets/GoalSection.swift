import SwiftUI

/// The cut, maintain or bulk choice that drives the calculator and the Today badge.
struct GoalSection: View {
    @Binding var goal: WeightGoal

    var body: some View {
        Section {
            Picker(selection: $goal) {
                ForEach(WeightGoal.allCases) { option in
                    Text(option.shortTitle)
                        .tag(option)
                }
            } label: {
                Text(.goalField)
            }
            .pickerStyle(.segmented)
        } header: {
            Text(.goalField)
        } footer: {
            Text(goal.title)
        }
    }
}

#Preview {
    @Previewable @State var goal = WeightGoal.cut
    Form {
        GoalSection(goal: $goal)
    }
}
