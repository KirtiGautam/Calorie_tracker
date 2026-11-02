import Foundation

nonisolated extension JSONDecoder {
    /// Decodes `type` from an API response body.
    ///
    /// - Throws: `APIError.decoding` when the body doesn't match `type`, so callers map one error rather than every
    ///   `DecodingError` case.
    func decodeResponse<Response: Decodable>(_ type: Response.Type, from data: Data) throws -> Response {
        do {
            return try decode(type, from: data)
        } catch is DecodingError {
            throw APIError.decoding
        }
    }
}
