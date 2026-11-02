import SwiftUI

/// The brand to limit Open Food Facts results to: one of the top brands, or one the person types.
struct BrandFilterSection: View {
    /// The brands on offer, in order.
    let brands: [BrandFilter]

    /// The brand picked from the list, or `nil` for any brand.
    @Binding var pickedBrand: BrandFilter?

    /// A brand the person typed, which wins over the picked one when it isn't blank.
    @Binding var typedBrand: String

    /// Called when the person submits the typed brand.
    let onSubmit: () -> Void

    var body: some View {
        Section {
            Picker(selection: $pickedBrand) {
                Text(.anyBrandOption).tag(BrandFilter?.none)
                ForEach(brands, id: \.self) { brand in
                    Text(brand.displayName).tag(Optional(brand))
                }
            } label: {
                Text(.brandFilterSection)
            }
            .pickerStyle(.inline)
            // The section header already names the list.
            .labelsHidden()

            TextField(.otherBrandField, text: $typedBrand)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit(onSubmit)
        } header: {
            Text(.brandFilterSection)
        } footer: {
            Text(.brandFilterFooter)
        }
    }
}

#Preview {
    @Previewable @State var pickedBrand: BrandFilter?
    @Previewable @State var typedBrand = ""
    Form {
        BrandFilterSection(
            brands: [BrandOption(tag: "parle", name: "Parle").filter, BrandOption(tag: "britannia", name: "Britannia").filter],
            pickedBrand: $pickedBrand,
            typedBrand: $typedBrand,
            onSubmit: {}
        )
    }
}
