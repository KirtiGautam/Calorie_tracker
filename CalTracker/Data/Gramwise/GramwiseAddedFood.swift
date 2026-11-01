/// A food to add to, or replace in, the server day `logDate`.
nonisolated struct GramwiseAddedFood: Encodable, Hashable, Sendable {
    /// The server day, such as `2026-10-29`.
    let logDate: String

    /// The food itself.
    let food: GramwiseLoggedFood

    private enum CodingKeys: String, CodingKey {
        case logDate = "log_date"
    }

    /// Encodes the food's fields and `log_date` side by side in one object, as the server expects.
    func encode(to encoder: any Encoder) throws {
        try food.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(logDate, forKey: .logDate)
    }
}
