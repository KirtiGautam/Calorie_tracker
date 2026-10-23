import Foundation

/// A `UserDefaults` suite unique to one test, removed when the test finishes.
final class IsolatedDefaults {
    let defaults: UserDefaults
    private let suiteName = "CalTrackerTests-\(UUID().uuidString)"

    init() {
        // A fresh UUID suite name is never the app's own domain, so creation can't fail.
        defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    isolated deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
