import Foundation
import Security
import Synchronization

/// Stores the Worker's bearer token. Implementations never log or print it.
nonisolated protocol TokenStore: Sendable {
    func read() throws -> String?
    func save(_ token: String) throws
    func delete() throws
}

nonisolated enum TokenStoreError: Error, Equatable, LocalizedError {
    case empty
    case keychain(OSStatus)
    case unexpectedData

    var errorDescription: String? {
        switch self {
        case .empty: "The token is empty."
        case .keychain(let status): "Keychain error (\(status))."
        case .unexpectedData: "The saved token couldn't be read."
        }
    }
}

nonisolated enum TokenNormalizer {
    /// Trims whitespace and newlines; rejects an empty result.
    static func normalize(_ token: String) throws(TokenStoreError) -> String {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .empty }
        return trimmed
    }
}

/// Generic-password Keychain item, this device only, readable after first unlock
/// (so background work in later phases can use it). Not synced to iCloud.
nonisolated struct KeychainTokenStore: TokenStore {
    let service: String
    let account: String

    init(service: String = "com.aurlaw.prepost.api", account: String = "bearer") {
        self.service = service
        self.account = account
    }

    private var baseQuery: [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
    }

    func read() throws -> String? {
        var query = baseQuery
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let token = String(data: data, encoding: .utf8) else {
                throw TokenStoreError.unexpectedData
            }
            return token
        case errSecItemNotFound:
            return nil
        default:
            throw TokenStoreError.keychain(status)
        }
    }

    func save(_ token: String) throws {
        let data = Data(try TokenNormalizer.normalize(token).utf8)
        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            let addStatus = SecItemAdd(baseQuery.merging(attributes) { $1 } as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw TokenStoreError.keychain(addStatus) }
        default:
            throw TokenStoreError.keychain(updateStatus)
        }
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw TokenStoreError.keychain(status)
        }
    }
}

/// For previews and tests.
nonisolated final class InMemoryTokenStore: TokenStore {
    private let token: Mutex<String?>

    init(token: String? = nil) {
        self.token = Mutex(token)
    }

    func read() throws -> String? {
        token.withLock { $0 }
    }

    func save(_ token: String) throws {
        let normalized = try TokenNormalizer.normalize(token)
        self.token.withLock { $0 = normalized }
    }

    func delete() throws {
        token.withLock { $0 = nil }
    }
}
