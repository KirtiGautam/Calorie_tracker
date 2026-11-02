import SwiftUI

/// A sheet for choosing how many grams of a food to log, with a live nutrient preview.
struct LogFoodView: View {
    @Environment(\.dismiss) private var dismiss

    /// Called after the food is saved, just before the sheet dismisses.
    let onLogged: (LoggedFood) -> Void

    @State private var viewModel: LogFoodViewModel
    @State private var failureMessage: LocalizedStringResource?

    /// Creates the sheet for `viewModel`, calling `onLogged` after the food is saved.
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
                    NumberFieldRow(.gramsField, value: $viewModel.grams, format: .number)
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
            .sheetActions(confirm: .logAction, isDisabled: viewModel.isValid == false, action: log)
            .errorAlert(.logFailedTitle, message: $failureMessage)
        }
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
