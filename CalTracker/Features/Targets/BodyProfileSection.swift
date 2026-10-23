import SwiftUI

/// The measurements the calculator uses, with the button that fills in suggested targets.
struct BodyProfileSection: View {
    @Bindable var viewModel: TargetsViewModel

    var body: some View {
        Section {
            Picker(selection: $viewModel.sex) {
                ForEach(BiologicalSex.allCases) { option in
                    Text(option.title)
                        .tag(option)
                }
            } label: {
                Text(.sexField)
            }

            LabeledContent {
                TextField(value: $viewModel.age, format: .number) {
                    Text(.ageField)
                }
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
            } label: {
                Text(.ageField)
            }

            LabeledContent {
                TextField(value: $viewModel.heightCentimetres, format: .number) {
                    Text(.heightField)
                }
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            } label: {
                Text(.heightField)
            }

            LabeledContent {
                TextField(value: $viewModel.weightKilograms, format: .number) {
                    Text(.weightField)
                }
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            } label: {
                Text(.weightField)
            }

            Picker(selection: $viewModel.activity) {
                ForEach(ActivityLevel.allCases) { option in
                    Text(option.title)
                        .tag(option)
                }
            } label: {
                Text(.activityField)
            }

            Button(.calculateAction, systemImage: "function", action: calculate)
                .disabled(viewModel.canCalculate == false)
        } header: {
            Text(.aboutYouSection)
        } footer: {
            Text(.calculatorFooter)
        }
    }

    private func calculate() {
        viewModel.calculate()
    }
}

#Preview {
    Form {
        BodyProfileSection(viewModel: AppDependencies.preview.makeTargetsViewModel())
    }
}
