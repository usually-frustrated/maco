import Foundation

enum ProfilePaths {
    static let appFolderName = "maco"
    static let profilesFolderName = "profiles"
    static let sharedAppGroupIdentifier = "group.com.macovpn.sharedprofiles"
    static let profileFileName = "config.ovpn"
    static let metadataFileName = "profile.json"

    static var legacyProfilesRootURL: URL {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return homeURL
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent(appFolderName, isDirectory: true)
            .appendingPathComponent(profilesFolderName, isDirectory: true)
    }

    static var sharedProfilesRootURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: sharedAppGroupIdentifier)?
            .appendingPathComponent(appFolderName, isDirectory: true)
            .appendingPathComponent(profilesFolderName, isDirectory: true)
    }

    static var profilesRootURL: URL {
        sharedProfilesRootURL ?? legacyProfilesRootURL
    }

    static func profileDirectoryURL(for id: UUID, rootURL: URL = profilesRootURL) -> URL {
        rootURL.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    static func profileFileURL(in directoryURL: URL) -> URL {
        directoryURL.appendingPathComponent(profileFileName)
    }

    static func metadataFileURL(in directoryURL: URL) -> URL {
        directoryURL.appendingPathComponent(metadataFileName)
    }
}
