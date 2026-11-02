import Foundation
import Testing
@testable import CalTracker

@Suite(.tags(.persistence))
struct SearchPreferencesStoreTests {
    private let isolated = IsolatedDefaults()

    @Test func freshStoreHasTheCountryFilterOff() {
        let store = SearchPreferencesStore(defaults: isolated.defaults)

        #expect(store.regionFilterEnabled == false)
        #expect(store.regionCode == nil)
        #expect(store.filters == FoodSearchFilters())
    }

    @Test func savedCountryFilterSurvivesReopening() {
        SearchPreferencesStore(defaults: isolated.defaults).save(regionFilterEnabled: true, regionCode: "IN")

        let reopened = SearchPreferencesStore(defaults: isolated.defaults)

        #expect(reopened.regionFilterEnabled)
        #expect(reopened.regionCode == "IN")
        #expect(reopened.filters == FoodSearchFilters(regionEnabled: true, regionCode: "IN"))
    }

    @Test func savingNoRegionRemovesTheOldOne() {
        SearchPreferencesStore(defaults: isolated.defaults).save(regionFilterEnabled: true, regionCode: "GB")
        SearchPreferencesStore(defaults: isolated.defaults).save(regionFilterEnabled: false, regionCode: nil)

        let reopened = SearchPreferencesStore(defaults: isolated.defaults)

        #expect(reopened.regionFilterEnabled == false)
        #expect(reopened.regionCode == nil)
    }

    @Test func readsTheLaunchArgumentSpellingOfTheToggle() {
        // UI tests pass `-search.regionFilterEnabled NO`, which arrives as a string.
        isolated.defaults.set("NO", forKey: "search.regionFilterEnabled")
        isolated.defaults.set("IN", forKey: "search.regionCode")

        #expect(SearchPreferencesStore(defaults: isolated.defaults).regionFilterEnabled == false)
    }
}
