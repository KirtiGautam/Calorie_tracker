import Foundation

nonisolated extension URLComponents {
    /// Sets `items` as the query, percent-encoding every character outside RFC 3986's unreserved set.
    ///
    /// `queryItems` leaves characters such as `(`, `)` and `+` as-is. USDA rejects raw parentheses
    /// with HTTP 400, and servers read a raw `+` as a space.
    mutating func setStrictlyEncodedQueryItems(_ items: [URLQueryItem]) {
        percentEncodedQueryItems = items.map { item in
            URLQueryItem(name: Self.strictlyEncoded(item.name), value: item.value.map(Self.strictlyEncoded))
        }
    }

    private static let unreservedCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    private static func strictlyEncoded(_ text: String) -> String {
        // Encoding only fails for invalid UTF-16, which Swift strings can't contain.
        text.addingPercentEncoding(withAllowedCharacters: unreservedCharacters) ?? text
    }
}
