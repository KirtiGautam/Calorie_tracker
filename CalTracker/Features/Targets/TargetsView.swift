import SwiftUI

/// A sheet for choosing a goal and daily targets, with a calculator that suggests them.
struct TargetsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: TargetsViewModel
    @State private var failureMessage: LocalizedStringResource?

    /// Creates the sheet for `viewModel`.
    init(viewModel: TargetsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                GoalSection(goal: $viewModel.goal)
                BodyProfileSection(viewModel: viewModel)
                TargetFieldsSection(targets: $viewModel.targets)
            }
            .navigationTitle(.targetsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .sheetActions(confirm: .saveAction, isDisabled: viewModel.isValid == false, action: save)
            .errorAlert(.saveFailedTitle, message: $failureMessage)
        }
    }

    private func save() {
        do {
            try viewModel.save()
            dismiss()
        } catch {
            failureMessage = userMessage(for: error)
        }
    }
}

#Preview {
    TargetsView(viewModel: AppDependencies.preview.makeTargetsViewModel())
}
