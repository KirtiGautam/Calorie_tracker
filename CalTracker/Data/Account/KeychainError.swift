import Security

/// A Keychain call that returned a failure status.
nonisolated struct KeychainError: Error, Equatable, Sendable {
    /// The `OSStatus` the Keychain returned.
    let status: OSStatus
}
