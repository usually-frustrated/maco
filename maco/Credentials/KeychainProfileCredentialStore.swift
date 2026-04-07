import Foundation
import Security

enum ProfileCredentialStoreError: Error, LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidStoredData

    var errorDescription: String? {
        switch self {
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

    init(serviceName: String = "frustrated.maco.credentials") {
        self.serviceName = serviceName
        jsonEncoder = JSONEncoder()
        jsonDecoder = JSONDecoder()
    }

    func loadCredentials(for profileID: UUID) throws -> ProfileCredentials? {
        var query = baseQuery(for: profileID)
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
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: profileID.uuidString,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(baseQuery(for: profileID) as CFDictionary, [kSecValueData as String: data] as CFDictionary)

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
        let status = SecItemDelete(baseQuery(for: profileID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ProfileCredentialStoreError.unexpectedStatus(status)
        }
    }

    func storedProfileIDs() throws -> [UUID] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let items = item as? [[String: Any]] else {
                throw ProfileCredentialStoreError.invalidStoredData
            }

            return items.compactMap { attributes in
                guard let account = attributes[kSecAttrAccount as String] as? String else {
                    return nil
                }
                return UUID(uuidString: account)
            }
        case errSecItemNotFound:
            return []
        default:
            throw ProfileCredentialStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery(for profileID: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: profileID.uuidString
        ]
    }

    private func decodeCredentials(from data: Data) throws -> ProfileCredentials {
        do {
            return try jsonDecoder.decode(ProfileCredentials.self, from: data)
        } catch {
            throw ProfileCredentialStoreError.invalidStoredData
        }
    }
}
