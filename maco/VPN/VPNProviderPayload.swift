import Foundation

struct VPNProviderPayload: Equatable, Sendable {
    static let managedByAppKey = "macoManagedByApp"
    static let profileIDKey = "macoProfileID"
    static let profileDirectoryPathKey = "macoProfileDirectoryPath"
    static let profileConfigPathKey = "macoProfileConfigPath"

    let profileID: UUID
    let profileDirectoryPath: String
    let profileConfigPath: String

    init(profileID: UUID, profileDirectoryPath: String, profileConfigPath: String) {
        self.profileID = profileID
        self.profileDirectoryPath = profileDirectoryPath
        self.profileConfigPath = profileConfigPath
    }

    init?(providerConfiguration: [String: Any]?) {
        guard let providerConfiguration,
              providerConfiguration[Self.managedByAppKey] as? Bool == true,
              let profileIDValue = providerConfiguration[Self.profileIDKey] as? String,
              let profileID = UUID(uuidString: profileIDValue),
              let profileDirectoryPath = providerConfiguration[Self.profileDirectoryPathKey] as? String,
              let profileConfigPath = providerConfiguration[Self.profileConfigPathKey] as? String
        else {
            return nil
        }

        self.profileID = profileID
        self.profileDirectoryPath = profileDirectoryPath
        self.profileConfigPath = profileConfigPath
    }

    var providerConfiguration: [String: Any] {
        [
            Self.managedByAppKey: true,
            Self.profileIDKey: profileID.uuidString,
            Self.profileDirectoryPathKey: profileDirectoryPath,
            Self.profileConfigPathKey: profileConfigPath
        ]
    }
}
