import Foundation
import NetworkExtension

struct PacketTunnelStartupContext {
    let payload: VPNProviderPayload
    let profileConfigData: Data
    let credentials: ProfileCredentials?
    /// Static challenge response (TOTP). Passed separately to OpenVPN3's
    /// ProvideCreds.response — must NOT be appended to the password.
    let otp: String?

    static func load(
        from providerProtocol: NETunnelProviderProtocol,
        options: [String: NSObject]? = nil
    ) throws -> PacketTunnelStartupContext {
        guard let payload = VPNProviderPayload(providerConfiguration: providerProtocol.providerConfiguration) else {
            throw PacketTunnelStartupError.invalidProviderPayload
        }

        guard let profileConfigData = payload.configContent.data(using: .utf8) else {
            throw PacketTunnelStartupError.invalidProviderPayload
        }

        // Credentials are always passed via startVPNTunnel(options:) from the main app.
        // The extension never accesses the keychain directly (SecTaskCreateFromSelf
        // is unreliable in extension processes on some development configurations).
        var credentials: ProfileCredentials?
        if let username = options?["username"] as? String,
           let password = options?["password"] as? String {
            credentials = ProfileCredentials(username: username, password: password)
        }

        if requiresSavedCredentials(in: profileConfigData), credentials == nil {
            throw PacketTunnelStartupError.missingSavedCredentials(payload.profileID)
        }

        // Keep OTP separate — OpenVPN3 expects it in ProvideCreds.response,
        // not concatenated into the password string.
        let otp = options?["otp"] as? String

        return PacketTunnelStartupContext(
            payload: payload,
            profileConfigData: profileConfigData,
            credentials: credentials,
            otp: (otp?.isEmpty == false) ? otp : nil
        )
    }

    private static func requiresSavedCredentials(in profileConfigData: Data) -> Bool {
        // profileConfigData is always derived from configContent.data(using: .utf8)
        guard let contents = String(data: profileConfigData, encoding: .utf8) else { return false }
        return contents.split(separator: "\n", omittingEmptySubsequences: false).contains { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#"), !line.hasPrefix(";") else { return false }
            return line.split(whereSeparator: { $0.isWhitespace }).first?.lowercased() == "auth-user-pass"
        }
    }
}
