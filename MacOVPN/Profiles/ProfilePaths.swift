import Foundation

enum ProfilePaths {
    static let appFolderName = "MacOVPN"
    static let profilesFolderName = "profiles"
    static let profileFileName = "config.ovpn"
    static let metadataFileName = "profile.json"

    static var profilesRootURL: URL {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return homeURL
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent(appFolderName, isDirectory: true)
            .appendingPathComponent(profilesFolderName, isDirectory: true)
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
