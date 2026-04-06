import AppKit
import Foundation

final class ProfileStore {
    static let shared = ProfileStore()

    private let fileManager: FileManager
    private let importer: ProfileImporter
    private let rootURL: URL
    private let legacyRootURL: URL
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    init(
        rootURL: URL = ProfilePaths.profilesRootURL,
        legacyRootURL: URL = ProfilePaths.legacyProfilesRootURL,
        fileManager: FileManager = .default,
        importer: ProfileImporter = ProfileImporter()
    ) {
        self.rootURL = rootURL
        self.legacyRootURL = legacyRootURL
        self.fileManager = fileManager
        self.importer = importer
        jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
    }

    var profilesFolderURL: URL { rootURL }

    func ensureStorageDirectory() throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try migrateLegacyStorageIfNeeded()
    }

    func importProfile(from sourceURL: URL) throws -> ProfileImportResult {
        try ensureStorageDirectory()
        let analysis = try importer.analyze(fileURL: sourceURL)
        let profileID = UUID()
        let profileDirectoryURL = ProfilePaths.profileDirectoryURL(for: profileID, rootURL: rootURL)

        do {
            try fileManager.createDirectory(at: profileDirectoryURL, withIntermediateDirectories: true)
            let copiedProfileURL = ProfilePaths.profileFileURL(in: profileDirectoryURL)
            try fileManager.copyItem(at: sourceURL, to: copiedProfileURL)

            let record = ProfileRecord(
                id: profileID,
                displayName: analysis.displayName,
                sourceFileName: sourceURL.lastPathComponent,
                importedAt: Date(),
                warnings: analysis.warnings
            )
            try write(record, to: profileDirectoryURL)
            return ProfileImportResult(record: record, copiedProfileURL: copiedProfileURL, warnings: analysis.warnings)
        } catch {
            try? fileManager.removeItem(at: profileDirectoryURL)
            throw error
        }
    }

    func listProfiles() throws -> [ProfileRecord] {
        try ensureStorageDirectory()
        let directories = try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        let records = directories.compactMap { directoryURL -> ProfileRecord? in
            guard let resourceValues = try? directoryURL.resourceValues(forKeys: [.isDirectoryKey]) else {
                return nil
            }
            guard resourceValues.isDirectory == true else {
                return nil
            }
            return try? readRecord(from: directoryURL)
        }

        return records.sorted { $0.importedAt > $1.importedAt }
    }

    func removeProfile(id: UUID) throws {
        let directoryURL = ProfilePaths.profileDirectoryURL(for: id, rootURL: rootURL)
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }
        try fileManager.removeItem(at: directoryURL)
    }

    @discardableResult
    func openProfilesFolder() -> Bool {
        try? ensureStorageDirectory()
        return NSWorkspace.shared.open(rootURL)
    }

    private func migrateLegacyStorageIfNeeded() throws {
        guard rootURL.standardizedFileURL != legacyRootURL.standardizedFileURL else {
            return
        }

        guard fileManager.fileExists(atPath: legacyRootURL.path) else {
            return
        }

        let legacyItems = try fileManager.contentsOfDirectory(
            at: legacyRootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        guard !legacyItems.isEmpty else {
            return
        }

        let currentItems = try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        guard currentItems.isEmpty else {
            return
        }

        for itemURL in legacyItems {
            let destinationURL = rootURL.appendingPathComponent(itemURL.lastPathComponent, isDirectory: true)
            if fileManager.fileExists(atPath: destinationURL.path) {
                continue
            }
            try fileManager.moveItem(at: itemURL, to: destinationURL)
        }
    }

    private func write(_ record: ProfileRecord, to directoryURL: URL) throws {
        let metadataURL = ProfilePaths.metadataFileURL(in: directoryURL)
        let data = try jsonEncoder.encode(record)
        try data.write(to: metadataURL, options: .atomic)
    }

    private func readRecord(from directoryURL: URL) throws -> ProfileRecord {
        let metadataURL = ProfilePaths.metadataFileURL(in: directoryURL)
        let data = try Data(contentsOf: metadataURL)
        return try jsonDecoder.decode(ProfileRecord.self, from: data)
    }
}
