/// The response to a push: every day it touched, after the merge.
nonisolated struct GramwiseChangedDays: Decodable, Sendable {
    /// The touched days.
    let days: [GramwiseDailyLog]
}
