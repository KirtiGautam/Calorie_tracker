import SwiftUI

/// The switch that limits Open Food Facts results to one country, and the row that picks the country.
struct CountryFilterSection: View {
    @Environment(\.locale) private var locale

    /// Whether the country filter is on.
    @Binding var isEnabled: Bool

    /// The chosen ISO 3166-1 region code, kept while the filter is off so it can be turned back on.
    @Binding var regionCode: String?

    var body: some View {
        Section {
            Toggle(.countryFilterToggle, isOn: $isEnabled.animation())
                .onChange(of: isEnabled) { _, isEnabled in
                    filterToggled(on: isEnabled)
                }
            if isEnabled {
                NavigationLink {
                    CountryPickerView(selection: $regionCode)
                } label: {
                    LabeledContent {
                        if let regionCode {
                            Text(locale.countryName(forRegionCode: regionCode))
                        }
                    } label: {
                        Text(.countryFilterRow)
                    }
                }
            }
        } header: {
            Text(.countryFilterSection)
        } footer: {
            Text(.countryFilterFooter)
        }
    }

    /// Starts from the phone's region the first time the filter is turned on.
    private func filterToggled(on isEnabled: Bool) {
        if isEnabled, regionCode == nil {
            regionCode = OFFCountry.supportedRegionCode(for: locale)
        }
    }
}

#Preview {
    @Previewable @State var isEnabled = true
    @Previewable @State var regionCode: String? = "IN"
    NavigationStack {
        Form {
            CountryFilterSection(isEnabled: $isEnabled, regionCode: $regionCode)
        }
    }
}
