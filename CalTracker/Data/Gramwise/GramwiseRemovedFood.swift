import Foundation

/// A food to remove from the server day `logDate`.
nonisolated struct GramwiseRemovedFood: Encodable, Hashable, Sendable {
    /// The server day, such as `2026-10-29`.
    let logDate: String

    /// The removed entry's sync ID.
    let entryID: UUID

    private enum CodingKeys: String, CodingKey {
        case logDate = "log_date"
        case entryID = "entry_id"
    }
}
