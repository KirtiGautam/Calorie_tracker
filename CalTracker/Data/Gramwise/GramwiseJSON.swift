import Foundation

/// The JSON coders for the Gramwise backend, which uses ISO 8601 dates with optional fractional seconds.
nonisolated enum GramwiseJSON {
    private static let fractionalSeconds = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let wholeSeconds = Date.ISO8601FormatStyle()

    /// An encoder that writes dates with millisecond precision.
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(fractionalSeconds))
        }
        return encoder
    }

    /// A decoder that reads dates with or without fractional seconds, such as the server's microseconds.
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            if let date = parseDate(text) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not an ISO 8601 date: \(text)")
        }
        return decoder
    }

    /// Parses an ISO 8601 timestamp, trimming fractional seconds beyond milliseconds first.
    static func parseDate(_ text: String) -> Date? {
        if let date = try? wholeSeconds.parse(text) {
            return date
        }
        // Python sends microseconds (.406083). Keep three digits, which the format style always accepts.
        let trimmed = text.replacing(/(\.\d{3})\d+/) { $0.output.1 }
        return try? fractionalSeconds.parse(trimmed)
    }
}
