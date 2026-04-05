import Foundation
import NetworkExtension

struct PacketTunnelStartupContext {
    let payload: VPNProviderPayload
    let profileDirectoryURL: URL
    let profileConfigURL: URL
    let profileConfigData: Data
    let credentials: ProfileCredentials?

    static func load(
        from providerProtocol: NETunnelProviderProtocol,
        credentialStore: ProfileCredentialStoring = KeychainProfileCredentialStore.shared
    ) throws -> PacketTunnelStartupContext {
        let fileManager = FileManager.default
        guard let payload = VPNProviderPayload(providerConfiguration: providerProtocol.providerConfiguration) else {
            throw PacketTunnelStartupError.invalidProviderPayload
        }

        let profileDirectoryURL = URL(fileURLWithPath: payload.profileDirectoryPath, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: profileDirectoryURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            throw PacketTunnelStartupError.missingProfileDirectory(profileDirectoryURL)
        }

        let profileConfigURL = URL(fileURLWithPath: payload.profileConfigPath)
        guard profileConfigURL.deletingLastPathComponent().standardizedFileURL == profileDirectoryURL.standardizedFileURL else {
            throw PacketTunnelStartupError.invalidProviderPayload
        }

        guard fileManager.fileExists(atPath: profileConfigURL.path) else {
            throw PacketTunnelStartupError.missingProfileConfig(profileConfigURL)
        }

        let profileConfigData: Data
        do {
            profileConfigData = try Data(contentsOf: profileConfigURL)
        } catch {
            throw PacketTunnelStartupError.unreadableProfileConfig(profileConfigURL, underlying: error)
        }

        let credentials = try credentialStore.loadCredentials(for: payload.profileID)
        if requiresSavedCredentials(in: profileConfigData), credentials == nil {
            throw PacketTunnelStartupError.missingSavedCredentials(payload.profileID)
        }

        return PacketTunnelStartupContext(
            payload: payload,
            profileDirectoryURL: profileDirectoryURL,
            profileConfigURL: profileConfigURL,
            profileConfigData: profileConfigData,
            credentials: credentials
        )
    }

    private static func requiresSavedCredentials(in profileConfigData: Data) -> Bool {
        let encodings: [String.Encoding] = [.utf8, .ascii, .isoLatin1, .windowsCP1252]
        guard let contents = encodings.compactMap({ String(data: profileConfigData, encoding: $0) }).first else {
            return false
        }

        return contents
            .split(separator: "\n", omittingEmptySubsequences: false)
            .contains { rawLine in
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !line.isEmpty, !line.hasPrefix("#"), !line.hasPrefix(";") else {
                    return false
                }

                guard let directive = line.split(whereSeparator: { $0.isWhitespace }).first else {
                    return false
                }

                return directive.lowercased() == "auth-user-pass"
            }
    }
}
