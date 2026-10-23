import SwiftUI

/// A sheet for choosing a goal and daily targets, with a calculator that suggests them.
struct TargetsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: TargetsViewModel
    @State private var failureMessage: LocalizedStringResource?

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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(.cancelAction, systemImage: "xmark", role: .cancel, action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(.saveAction, systemImage: "checkmark", action: save)
                        .disabled(viewModel.isValid == false)
                }
            }
            .alert(.saveFailedTitle, item: $failureMessage) { _ in
            } message: { message in
                Text(message)
            }
        }
    }

    private func cancel() {
        dismiss()
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
