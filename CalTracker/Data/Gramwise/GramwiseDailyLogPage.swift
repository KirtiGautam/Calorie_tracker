/// One page of days changed since a cursor.
nonisolated struct GramwiseDailyLogPage: Decodable, Hashable, Sendable {
    /// The changed days, oldest change first.
    let days: [GramwiseDailyLog]

    /// Where the next request should resume. Stored after a pull so the next one only sees newer changes.
    let nextCursor: String?

    /// Whether more changed days remain after this page.
    let hasMore: Bool

    private enum CodingKeys: String, CodingKey {
        case days
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}
