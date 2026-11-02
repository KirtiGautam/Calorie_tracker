import Foundation
import Testing

/// Loads fixtures bundled with the test target.
final class FixtureLoader {
    /// Returns the contents of `name.json` from the test bundle.
    static func data(named name: String, sourceLocation: SourceLocation = #_sourceLocation) throws -> Data {
        try Data(contentsOf: url(named: name, withExtension: "json", sourceLocation: sourceLocation))
    }

    /// Returns the URL of `name.fileExtension` in the test bundle.
    static func url(
        named name: String,
        withExtension fileExtension: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> URL {
        let bundle = Bundle(for: FixtureLoader.self)
        return try #require(
            bundle.url(forResource: name, withExtension: fileExtension),
            "Missing fixture \(name).\(fileExtension)",
            sourceLocation: sourceLocation
        )
    }
}
