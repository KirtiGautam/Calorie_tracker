import SwiftUI

/// A searchable list of the countries Open Food Facts can filter by, with the phone's region first.
struct CountryPickerView: View {
    /// The chosen ISO 3166-1 region code.
    @Binding var selection: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @State private var searchText = ""

    var body: some View {
        List {
            if searchText.isEmpty, let currentRegion {
                Section(.countryPickerCurrentSection) {
                    row(for: currentRegion)
                }
            }
            Section(.countryPickerAllSection) {
                ForEach(countries, id: \.code) { country in
                    row(for: country)
                }
            }
        }
        .navigationTitle(.countryPickerTitle)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: .countryPickerPrompt)
        .autocorrectionDisabled()
    }

    /// The phone's region, when Open Food Facts has a country for it.
    private var currentRegion: Country? {
        OFFCountry.supportedRegionCode(for: locale).map(country(for:))
    }

    /// Every supported country matching the search text, sorted by its name in the current language.
    private var countries: [Country] {
        OFFCountry.supportedRegionCodes
            .map(country(for:))
            .filter { searchText.isEmpty || $0.name.localizedStandardContains(searchText) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func country(for code: String) -> Country {
        Country(code: code, name: locale.countryName(forRegionCode: code))
    }

    private func row(for country: Country) -> some View {
        Button {
            selection = country.code
            dismiss()
        } label: {
            HStack {
                Text(country.name)
                    .foregroundStyle(.primary)
                Spacer()
                if selection == country.code {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityAddTraits(selection == country.code ? .isSelected : [])
    }

    /// A region code with its localized name.
    private struct Country {
        /// The ISO 3166-1 region code, such as "IN".
        let code: String

        /// The country's name in the current language.
        let name: String
    }
}

#Preview {
    @Previewable @State var selection: String? = "IN"
    NavigationStack {
        CountryPickerView(selection: $selection)
    }
}
