import NetworkExtension
import os.log

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private let logger = Logger(subsystem: "com.macovpn.app.packet-tunnel", category: "PacketTunnel")

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        do {
            let startupContext = try resolveStartupContext()
            logger.log("Resolved packet tunnel startup for profile \(startupContext.payload.profileID.uuidString, privacy: .public)")
            logger.log("Loaded profile config at \(startupContext.profileConfigURL.path, privacy: .public)")
            if startupContext.credentials != nil {
                logger.log("Loaded shared credentials for profile \(startupContext.payload.profileID.uuidString, privacy: .public)")
            }
            completionHandler(PacketTunnelStartupError.openVPNCoreNotImplemented)
        } catch {
            logger.error("Packet tunnel startup failed: \(error.localizedDescription, privacy: .public)")
            completionHandler(error)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.log("Packet tunnel stopped with reason: \(reason.rawValue, privacy: .public)")
        completionHandler()
    }

    private func resolveStartupContext() throws -> PacketTunnelStartupContext {
        guard let providerProtocol = protocolConfiguration as? NETunnelProviderProtocol else {
            throw PacketTunnelStartupError.invalidProviderPayload
        }
        return try PacketTunnelStartupContext.load(from: providerProtocol)
    }
}
