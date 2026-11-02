import Foundation

extension Locale {
    /// Returns the name of the country with ISO 3166-1 `regionCode` in this locale's language, or the code itself
    /// when the locale has no name for it.
    func countryName(forRegionCode regionCode: String) -> String {
        localizedString(forRegionCode: regionCode) ?? regionCode
    }
}
