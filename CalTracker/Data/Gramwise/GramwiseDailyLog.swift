import Foundation

/// One server day with its foods.
nonisolated struct GramwiseDailyLog: Decodable, Hashable, Sendable {
    /// The day, such as `2026-10-29`.
    let logDate: String

    /// Every food logged that day. Empty when they were all deleted.
    let foods: [GramwiseLoggedFood]

    /// When the server last changed the day.
    let updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case logDate = "log_date"
        case foods
        case updatedAt = "updated_at"
    }
}
