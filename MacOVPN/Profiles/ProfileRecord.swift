import Foundation

struct ProfileImportWarning: Codable, Equatable, Sendable {
    let line: Int
    let directive: String
    let message: String
}

struct ProfileRecord: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let displayName: String
    let sourceFileName: String
    let importedAt: Date
    let warnings: [ProfileImportWarning]

    func directoryURL(in rootURL: URL = ProfilePaths.profilesRootURL) -> URL {
        ProfilePaths.profileDirectoryURL(for: id, rootURL: rootURL)
    }
}

struct ProfileImportResult {
    let record: ProfileRecord
    let copiedProfileURL: URL
    let warnings: [ProfileImportWarning]
}
