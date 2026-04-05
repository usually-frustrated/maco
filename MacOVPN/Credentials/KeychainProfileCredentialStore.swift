import Foundation
import Security

enum ProfileCredentialStoreError: Error, LocalizedError {
    case missingAccessGroup
    case unexpectedStatus(OSStatus)
    case invalidStoredData

    var errorDescription: String? {
        switch self {
        case .missingAccessGroup:
            return "Keychain access group is unavailable."
        case .unexpectedStatus(let status):
            return SecCopyErrorMessageString(status, nil) as String? ?? "Keychain operation failed."
        case .invalidStoredData:
            return "Stored credentials could not be decoded."
        }
    }
}

final class KeychainProfileCredentialStore: ProfileCredentialStoring {
    static let shared = KeychainProfileCredentialStore()

    private let serviceName: String
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    init(serviceName: String = "com.macovpn.credentials") {
        self.serviceName = serviceName
        jsonEncoder = JSONEncoder()
        jsonDecoder = JSONDecoder()
    }

    func loadCredentials(for profileID: UUID) throws -> ProfileCredentials? {
        var query = try baseQuery(for: profileID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw ProfileCredentialStoreError.invalidStoredData
            }
            return try decodeCredentials(from: data)
        case errSecItemNotFound:
            return nil
        default:
            throw ProfileCredentialStoreError.unexpectedStatus(status)
        }
    }

    func saveCredentials(_ credentials: ProfileCredentials, for profileID: UUID) throws {
        let data = try jsonEncoder.encode(credentials)
        let accessGroup = try keychainAccessGroup()
        let attributes: [String: Any] = [
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: profileID.uuidString,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrAccessGroup as String: accessGroup,
            kSecValueData as String: data
        ]

        let query = try identityQuery(for: profileID)
        let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            let addStatus = SecItemAdd(attributes as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw ProfileCredentialStoreError.unexpectedStatus(addStatus)
            }
        default:
            throw ProfileCredentialStoreError.unexpectedStatus(updateStatus)
        }
    }

    func removeCredentials(for profileID: UUID) throws {
        let status = SecItemDelete(try identityQuery(for: profileID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ProfileCredentialStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery(for profileID: UUID) throws -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: profileID.uuidString,
            kSecAttrAccessGroup as String: try keychainAccessGroup()
        ]
    }

    private func identityQuery(for profileID: UUID) throws -> [String: Any] {
        try baseQuery(for: profileID)
    }

    private func keychainAccessGroup() throws -> String {
        guard let task = SecTaskCreateFromSelf(kCFAllocatorDefault) else {
            throw ProfileCredentialStoreError.missingAccessGroup
        }

        guard let groups = SecTaskCopyValueForEntitlement(task, "keychain-access-groups" as CFString, nil) as? [String],
              let accessGroup = groups.first else {
            throw ProfileCredentialStoreError.missingAccessGroup
        }

        return accessGroup
    }

    private func decodeCredentials(from data: Data) throws -> ProfileCredentials {
        do {
            return try jsonDecoder.decode(ProfileCredentials.self, from: data)
        } catch {
            throw ProfileCredentialStoreError.invalidStoredData
        }
    }
}
