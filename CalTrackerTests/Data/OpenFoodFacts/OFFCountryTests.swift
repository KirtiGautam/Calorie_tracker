import Foundation
import Testing
@testable import CalTracker

struct OFFCountryTests {
    @Test(arguments: [
        ("IN", "en:india"),
        ("GB", "en:united-kingdom"),
        ("CZ", "en:czech-republic"),
        ("us", "en:united-states"),
    ])
    func mapsRegionCodesToCountryTags(code: String, tag: String) {
        #expect(OFFCountry.tag(forRegionCode: code) == tag)
    }

    @Test(arguments: ["ZZ", "419", "", "UK"])
    func unknownRegionCodesHaveNoTag(code: String) {
        #expect(OFFCountry.tag(forRegionCode: code) == nil)
    }

    @Test func supportedRegionCodesAreSortedAndEachHasATag() {
        let codes = OFFCountry.supportedRegionCodes

        #expect(codes.count > 240)
        #expect(codes == codes.sorted())
        #expect(codes.allSatisfy { OFFCountry.tag(forRegionCode: $0) != nil })
    }

    @Test(arguments: [("en_IN", "IN"), ("cs_CZ", "CZ"), ("en_GB", "GB")])
    func readsTheSupportedRegionOfALocale(identifier: String, expected: String) {
        #expect(OFFCountry.supportedRegionCode(for: Locale(identifier: identifier)) == expected)
    }

    @Test(arguments: ["en", "en_001", "es_419"])
    func aLocaleWithoutASupportedCountryHasNoRegion(identifier: String) {
        #expect(OFFCountry.supportedRegionCode(for: Locale(identifier: identifier)) == nil)
    }
}
