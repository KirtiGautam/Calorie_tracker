import Foundation

/// Settings for the USDA FoodData Central API.
nonisolated struct USDAConfiguration: Sendable {
    /// The public, rate-limited key used when no personal key is configured.
    static let demoKey = "DEMO_KEY"

    /// The Info.plist key that holds `$(USDA_API_KEY)` from the xcconfig files.
    static let infoPlistKey = "USDAAPIKey"

    /// The API key sent with every request.
    let apiKey: String

    /// Creates a configuration with an explicit key.
    init(apiKey: String) {
        self.apiKey = apiKey
    }

    /// Reads the key from `bundle`'s Info.plist, falling back to `DEMO_KEY` when it's missing or unexpanded.
    init(bundle: Bundle) {
        let value = (bundle.object(forInfoDictionaryKey: Self.infoPlistKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isUsable = value.isEmpty == false && value.hasPrefix("$(") == false
        apiKey = isUsable ? value : Self.demoKey
    }
}
