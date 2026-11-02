import Foundation
import Observation

/// Keeps the search country filter in `UserDefaults`, so it survives relaunches.
///
/// The brand filter isn't saved, because the brands on offer depend on the query.
@Observable
final class SearchPreferencesStore {
    /// Whether Open Food Facts results are limited to `regionCode`.
    private(set) var regionFilterEnabled: Bool

    /// The ISO 3166-1 region code last chosen, such as "IN", or `nil` if none has been chosen.
    private(set) var regionCode: String?

    @ObservationIgnored private let defaults: UserDefaults

    /// Creates a store that reads and writes `defaults`.
    init(defaults: UserDefaults) {
        self.defaults = defaults
        regionFilterEnabled = defaults.bool(forKey: Key.regionFilterEnabled)
        regionCode = defaults.string(forKey: Key.regionCode)
    }

    /// The saved country filter, with no brand.
    var filters: FoodSearchFilters {
        FoodSearchFilters(regionEnabled: regionFilterEnabled, regionCode: regionCode)
    }

    /// Saves the country filter. A `nil` region code removes the saved one.
    func save(regionFilterEnabled: Bool, regionCode: String?) {
        defaults.set(regionFilterEnabled, forKey: Key.regionFilterEnabled)
        if let regionCode {
            defaults.set(regionCode, forKey: Key.regionCode)
        } else {
            defaults.removeObject(forKey: Key.regionCode)
        }
        self.regionFilterEnabled = regionFilterEnabled
        self.regionCode = regionCode
    }

    private enum Key {
        static let regionFilterEnabled = "search.regionFilterEnabled"
        static let regionCode = "search.regionCode"
    }
}
