import Foundation
import Security

/// Keeps the tokens in one Keychain item, readable after the first unlock and never synced or backed up off the device.
///
/// Keychain items outlive the app, so reinstalling within the refresh token's lifetime signs straight back in.
/// It's an actor so the Keychain calls run off the main actor, one at a time.
actor KeychainTokenStore: TokenStoring {
    /// The Keychain service the item is stored under.
    static let service = "com.kirti.Gramwise.account"

    /// The Keychain account the item is stored under.
    static let account = "session"

    func load() throws -> GramwiseTokenPair? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            // Data that doesn't decode can't sign in, and the next sign-in replaces it.
            guard let data = result as? Data else { return nil }
            return try? JSONDecoder().decode(GramwiseTokenPair.self, from: data)
        case errSecItemNotFound:
            return nil
        default:
            // For example errSecInteractionNotAllowed before the first unlock after a restart. Reporting no tokens
            // would sign out until the next launch, so the caller tries again later instead.
            throw KeychainError(status: status)
        }
    }

    func save(_ tokens: GramwiseTokenPair) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: try JSONEncoder().encode(tokens),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            let addStatus = SecItemAdd(baseQuery.merging(attributes) { $1 } as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
        default:
            throw KeychainError(status: updateStatus)
        }
    }

    func clear() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
        ]
    }
}
