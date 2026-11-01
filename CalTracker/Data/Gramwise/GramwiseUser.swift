import Foundation

/// The signed-in account as the backend describes it.
nonisolated struct GramwiseUser: Codable, Hashable, Sendable {
    /// The account's ID, which sync uses to notice a switch to another account.
    let id: UUID

    /// The account's email, trimmed and lowercased by the server.
    let email: String
}
