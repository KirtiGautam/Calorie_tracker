import Testing
@testable import CalTracker

struct OFFSearchQueryTests {
    @Test func textIsUnchangedWithoutFilters() {
        #expect(OFFSearchQuery.text(for: #"M&M's "peanut" (big)"#, filters: FoodSearchFilters()) == #"M&M's "peanut" (big)"#)
    }

    @Test func textIsUnchangedWhenTheCountryFilterIsOff() {
        let filters = FoodSearchFilters(regionEnabled: false, regionCode: "IN")

        #expect(OFFSearchQuery.text(for: "biscuit", filters: filters) == "biscuit")
    }

    @Test func textIsUnchangedForARegionOFFDoesNotKnow() {
        let filters = FoodSearchFilters(regionEnabled: true, regionCode: "419")

        #expect(OFFSearchQuery.text(for: "biscuit", filters: filters) == "biscuit")
    }

    @Test func addsTheCountryClause() {
        let filters = FoodSearchFilters(regionEnabled: true, regionCode: "IN")

        #expect(OFFSearchQuery.text(for: "chocolate biscuit", filters: filters) == #"chocolate biscuit countries_tags:"en:india""#)
    }

    @Test func addsTheBrandTagClause() {
        let filters = FoodSearchFilters(brand: .tag("parle", name: "Parle"))

        #expect(OFFSearchQuery.text(for: "biscuit", filters: filters) == #"biscuit brands_tags:"parle""#)
    }

    @Test func aTypedBrandMatchesItsTagOrItsSpelling() {
        let filters = FoodSearchFilters(regionEnabled: true, regionCode: "GB", brand: .name("Lay's"))

        #expect(
            OFFSearchQuery.text(for: "chips", filters: filters)
                == #"chips countries_tags:"en:united-kingdom" (brands_tags:"lay-s" OR brands:"Lay's")"#
        )
    }

    @Test func aPunctuationOnlyBrandMatchesOnlyItsSpelling() {
        #expect(OFFSearchQuery.text(for: "chips", filters: FoodSearchFilters(brand: .name("!!"))) == #"chips brands:"!!""#)
    }

    @Test func stripsCharactersThatWouldChangeTheQueryWhenFiltersFollow() {
        let filters = FoodSearchFilters(brand: .name(#"Bad "Brand\"#))

        #expect(
            OFFSearchQuery.text(for: #"  "rolled" (oats) \ brands:x  "#, filters: filters)
                == #"rolled oats brands x (brands_tags:"bad-brand" OR brands:"Bad Brand")"#
        )
    }

    @Test(arguments: [
        ("Lay's", "lay-s"),
        ("Nestlé", "nestle"),
        ("M&M's", "m-m-s"),
        ("Karachi Bakery", "karachi-bakery"),
        ("  -Parle- ", "parle"),
    ])
    func tagSpelling(brand: String, tag: String) {
        #expect(OFFSearchQuery.tag(for: brand) == tag)
    }
}
