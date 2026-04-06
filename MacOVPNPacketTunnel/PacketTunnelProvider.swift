import NetworkExtension
import os.log

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private let logger = Logger(subsystem: "com.macovpn.app.packet-tunnel", category: "PacketTunnel")
    private var bridge: OpenVPNPacketTunnelBridge?

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

            let bridge = OpenVPNPacketTunnelBridge(
                profileConfigURL: startupContext.profileConfigURL,
                profileID: startupContext.payload.profileID,
                username: startupContext.credentials?.username,
                password: startupContext.credentials?.password
            )
            self.bridge = bridge

            bridge.start(
                withPacketFlow: packetFlow,
                applySettings: { [weak self] (settings: NEPacketTunnelNetworkSettings, settingsCompletion: @escaping (Error?) -> Void) in
                    guard let self else {
                        settingsCompletion(NSError(
                            domain: "com.macovpn.packet-tunnel",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Packet tunnel provider is no longer available."]
                        ))
                        return
                    }

                    self.setTunnelNetworkSettings(settings) { error in
                        settingsCompletion(error)
                    }
                },
                completion: { error in
                    completionHandler(error)
                }
            )
        } catch {
            logger.error("Packet tunnel startup failed: \(error.localizedDescription, privacy: .public)")
            completionHandler(error)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.log("Packet tunnel stopped with reason: \(reason.rawValue, privacy: .public)")
        bridge?.stop()
        bridge = nil
        completionHandler()
    }

    private func resolveStartupContext() throws -> PacketTunnelStartupContext {
        guard let providerProtocol = protocolConfiguration as? NETunnelProviderProtocol else {
            throw PacketTunnelStartupError.invalidProviderPayload
        }
        return try PacketTunnelStartupContext.load(from: providerProtocol)
    }
}
