import SwiftUI

/// A sheet for choosing how many grams of a food to log, with a live nutrient preview.
struct LogFoodView: View {
    @Environment(\.dismiss) private var dismiss

    /// Called after the food is saved, just before the sheet dismisses.
    let onLogged: (LoggedFood) -> Void

    @State private var viewModel: LogFoodViewModel
    @State private var failureMessage: LocalizedStringResource?

    init(viewModel: LogFoodViewModel, onLogged: @escaping (LoggedFood) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onLogged = onLogged
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    FoodSummaryHeader(food: viewModel.food)
                }

                Section {
                    LabeledContent {
                        TextField(value: $viewModel.grams, format: .number) {
                            Text(.gramsField)
                        }
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    } label: {
                        Text(.gramsField)
                    }
                    GramPresetButtons(grams: $viewModel.grams)
                } header: {
                    Text(.amountSection)
                }

                Section {
                    NutrientTable(profile: viewModel.preview)
                } header: {
                    Text(.nutritionSection)
                }
            }
            .navigationTitle(.logFoodTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(.cancelAction, systemImage: "xmark", role: .cancel, action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(.logAction, systemImage: "checkmark", action: log)
                        .disabled(viewModel.isValid == false)
                }
            }
            .alert(.logFailedTitle, item: $failureMessage) { _ in
            } message: { message in
                Text(message)
            }
        }
    }

    private func cancel() {
        dismiss()
    }

    private func log() {
        do {
            onLogged(try viewModel.log())
            dismiss()
        } catch {
            failureMessage = userMessage(for: error)
        }
    }
}

#Preview {
    LogFoodView(viewModel: AppDependencies.preview.makeLogFoodViewModel(food: .previewBanana)) { _ in }
}
