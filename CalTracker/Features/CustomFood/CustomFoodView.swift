import SwiftUI

/// A sheet for entering a food from a label or a recipe, with a live preview of its nutrients per 100 g.
struct CustomFoodView: View {
    /// Called with the saved food. The caller replaces this sheet with the log sheet, which dismisses it.
    let onSaved: (CustomFoodRecord) -> Void

    @State private var viewModel: CustomFoodViewModel
    @State private var failureMessage: LocalizedStringResource?
    @State private var showsMicronutrients = false

    /// Creates the sheet for `viewModel`, calling `onSaved` after the food is saved.
    init(viewModel: CustomFoodViewModel, onSaved: @escaping (CustomFoodRecord) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(text: $viewModel.draft.name, prompt: Text(.customFoodNamePrompt)) {
                        Text(.customFoodNameField)
                    }
                    .accessibilityIdentifier("customFoodName")
                    NumberFieldRow(
                        .customFoodWeightField,
                        value: $viewModel.draft.referenceGrams,
                        format: .number,
                        unit: NutrientUnit.grams.symbol
                    )
                } footer: {
                    Text(.customFoodWeightFooter)
                }

                Section {
                    ForEach(Nutrient.macros) { nutrient in
                        NutrientEntryRow(nutrient: nutrient, draft: $viewModel.draft)
                    }
                } header: {
                    Text(.customFoodMacrosSection)
                } footer: {
                    Text(.customFoodEnergyFooter)
                }

                Section {
                    DisclosureGroup(isExpanded: $showsMicronutrients) {
                        ForEach(Nutrient.micros) { nutrient in
                            NutrientEntryRow(nutrient: nutrient, draft: $viewModel.draft)
                        }
                    } label: {
                        Text(.micronutrientsTitle)
                    }
                }

                Section {
                    NutrientTable(profile: viewModel.preview ?? NutrientProfile(), nutrients: viewModel.previewNutrients)
                } header: {
                    Text(.customFoodPreviewSection)
                } footer: {
                    if let issue = viewModel.issue {
                        Text(issue)
                    }
                }
            }
            .navigationTitle(.customFoodTitle)
            .navigationBarTitleDisplayMode(.inline)
            .sheetActions(confirm: .saveAction, isDisabled: viewModel.canSave == false, action: save)
            .errorAlert(.customFoodSaveFailedTitle, message: $failureMessage)
        }
    }

    private func save() {
        do {
            onSaved(try viewModel.save())
        } catch {
            failureMessage = userMessage(for: error)
        }
    }
}

#Preview {
    CustomFoodView(viewModel: AppDependencies.preview.makeCustomFoodViewModel(name: "Grandma's dal")) { _ in }
}
