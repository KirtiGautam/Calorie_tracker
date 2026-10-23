import Foundation
import Testing

/// Loads JSON fixtures bundled with the test target.
final class FixtureLoader {
    /// Returns the contents of `name.json` from the test bundle.
    static func data(named name: String, sourceLocation: SourceLocation = #_sourceLocation) throws -> Data {
        let bundle = Bundle(for: FixtureLoader.self)
        let url = try #require(
            bundle.url(forResource: name, withExtension: "json"),
            "Missing fixture \(name).json",
            sourceLocation: sourceLocation
        )
        return try Data(contentsOf: url)
    }
}
