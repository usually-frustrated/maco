import Foundation

struct VPNProviderPayload: Equatable, Sendable {
    static let managedByAppKey = "macoManagedByApp"
    static let profileIDKey = "macoProfileID"
    static let displayNameKey = "macoDisplayName"
    static let configContentKey = "macoConfigContent"

    let profileID: UUID
    let displayName: String
    let configContent: String

    init(profileID: UUID, displayName: String, configContent: String) {
        self.profileID = profileID
        self.displayName = displayName
        self.configContent = configContent
    }

    init?(providerConfiguration: [String: Any]?) {
        guard let providerConfiguration,
              providerConfiguration[Self.managedByAppKey] as? Bool == true,
              let profileIDValue = providerConfiguration[Self.profileIDKey] as? String,
              let profileID = UUID(uuidString: profileIDValue),
              let displayName = providerConfiguration[Self.displayNameKey] as? String,
              let configContent = providerConfiguration[Self.configContentKey] as? String
        else {
            return nil
        }

        self.profileID = profileID
        self.displayName = displayName
        self.configContent = configContent
    }

    var providerConfiguration: [String: Any] {
        [
            Self.managedByAppKey: true,
            Self.profileIDKey: profileID.uuidString,
            Self.displayNameKey: displayName,
            Self.configContentKey: configContent
        ]
    }
}
