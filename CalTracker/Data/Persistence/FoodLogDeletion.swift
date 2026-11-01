import Foundation
import SwiftData

/// The current version of a deletion that still has to reach the server.
typealias FoodLogDeletion = SchemaV2.FoodLogDeletion

extension SchemaV2 {
    /// A tombstone for a synced entry the person deleted. The next sync sends it and removes it.
    @Model
    final class FoodLogDeletion {
        /// The deleted entry's `FoodLogEntry.syncID`.
        var syncID: UUID = UUID()

        /// The server day the entry was stored under, such as `2026-10-29`.
        var day: String = ""

        /// Creates a tombstone for the entry with `syncID` stored under `day`.
        init(syncID: UUID, day: String) {
            self.syncID = syncID
            self.day = day
        }
    }
}
