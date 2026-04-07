import Foundation

enum PacketTunnelStartupError: LocalizedError {
    case invalidProviderPayload
    case missingSavedCredentials(UUID)
    case openVPNCoreNotImplemented

    var errorDescription: String? {
        switch self {
        case .invalidProviderPayload:
            return "Provider payload is missing or invalid. [maco.tunnel.startup 1]"
        case .missingSavedCredentials(let profileID):
            return "No credentials found for profile \(profileID.uuidString). Re-enter credentials via Set Saved Credentials. [maco.tunnel.startup 5]"
        case .openVPNCoreNotImplemented:
            return "OpenVPN core is not implemented. [maco.tunnel.startup 6]"
        }
    }
}
