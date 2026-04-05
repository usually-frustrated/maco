import Foundation

enum PacketTunnelStartupError: LocalizedError {
    case invalidProviderPayload
    case missingProfileDirectory(URL)
    case missingProfileConfig(URL)
    case unreadableProfileConfig(URL, underlying: Error)
    case missingSavedCredentials(UUID)
    case openVPNCoreNotImplemented

    var errorDescription: String? {
        switch self {
        case .invalidProviderPayload:
            return "Provider payload is missing or invalid."
        case .missingProfileDirectory(let url):
            return "Profile directory is missing: \(url.path)"
        case .missingProfileConfig(let url):
            return "Profile config is missing: \(url.path)"
        case .unreadableProfileConfig(let url, let underlying):
            return "Profile config could not be read: \(url.path) (\(underlying.localizedDescription))"
        case .missingSavedCredentials(let profileID):
            return "Saved credentials are missing for profile \(profileID.uuidString)."
        case .openVPNCoreNotImplemented:
            return "OpenVPN core integration is not implemented yet."
        }
    }
}
