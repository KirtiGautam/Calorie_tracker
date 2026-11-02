import SwiftUI

/// The measurements the calculator uses, with the button that fills in suggested targets.
struct BodyProfileSection: View {
    /// The draft the fields edit.
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

            NumberFieldRow(.ageField, value: $viewModel.age, format: .number, keyboard: .numberPad)
            NumberFieldRow(.heightField, value: $viewModel.heightCentimetres, format: .number)
            NumberFieldRow(.weightField, value: $viewModel.weightKilograms, format: .number)

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
