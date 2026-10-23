import Foundation
@testable import CalTracker

extension Loadable {
    /// Whether the state is `.idle`.
    var isIdle: Bool {
        if case .idle = self { true } else { false }
    }

    /// Whether the state is `.loading`.
    var isLoading: Bool {
        if case .loading = self { true } else { false }
    }

    /// The loaded value, or `nil` in any other state.
    var loadedValue: Value? {
        if case .loaded(let value) = self { value } else { nil }
    }

    /// The failure message, or `nil` in any other state.
    var failureMessage: LocalizedStringResource? {
        if case .failed(let message) = self { message } else { nil }
    }
}
