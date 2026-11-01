import Foundation

/// Settings for the Gramwise backend.
nonisolated struct GramwiseConfiguration: Sendable {
    /// The backend used when Info.plist has no usable URL: one running on this Mac.
    static let localBaseURL = URL(string: "http://localhost:8000") ?? URL(filePath: "/")

    /// The Info.plist key that holds `$(GRAMWISE_API_BASE_URL)` from the xcconfig files.
    static let infoPlistKey = "GramwiseAPIBaseURL"

    /// The URL every request path is resolved against.
    let baseURL: URL

    /// Creates a configuration with an explicit base URL.
    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    /// Reads the base URL from `bundle`'s Info.plist, falling back to `localBaseURL` when it's missing, unexpanded or invalid.
    init(bundle: Bundle) {
        let value = (bundle.object(forInfoDictionaryKey: Self.infoPlistKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let url = value.hasPrefix("$(") ? nil : URL(string: value)
        let isUsable = url?.scheme == "https" || url?.scheme == "http"
        baseURL = isUsable ? url ?? Self.localBaseURL : Self.localBaseURL
    }
}
