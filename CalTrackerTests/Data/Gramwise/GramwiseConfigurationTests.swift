import Foundation
import Testing
@testable import CalTracker

struct GramwiseConfigurationTests {
    @Test func appBundleHasAUsableURL() {
        let configuration = GramwiseConfiguration(bundle: .main)

        #expect(["http", "https"].contains(configuration.baseURL.scheme))
    }

    @Test func missingKeyFallsBackToLocalBackend() {
        let configuration = GramwiseConfiguration(bundle: Bundle(for: FixtureLoader.self))

        #expect(configuration.baseURL == GramwiseConfiguration.localBaseURL)
    }
}
