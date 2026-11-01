import Foundation

/// Where cloud sync stands, shown by the cloud on Today and in the account sheet.
nonisolated enum SyncStatus: Equatable, Sendable {
    /// There's no account on this device, so nothing is backed up.
    case signedOut

    /// A sync pass is running.
    case syncing

    /// The last pass finished at the given moment.
    case upToDate(Date)

    /// The last pass failed with a message ready to show the person.
    case failed(LocalizedStringResource)
}
