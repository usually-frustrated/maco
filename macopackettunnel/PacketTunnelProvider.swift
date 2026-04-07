import NetworkExtension
import os.log

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private let logger = Logger(subsystem: "com.macovpn.app.packet-tunnel", category: "PacketTunnel")
    private var bridge: OpenVPNPacketTunnelBridge?

    private static func unavailableError() -> NSError {
        NSError(
            domain: "com.macovpn.packet-tunnel",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Packet tunnel provider is no longer available."]
        )
    }

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else {
                completionHandler(Self.unavailableError())
                return
            }

            do {
                let startupContext = try self.resolveStartupContext(options: options)
                let profileID = startupContext.payload.profileID
                self.logger.log("Resolved packet tunnel startup for profile \(profileID.uuidString, privacy: .public)")
                if startupContext.credentials != nil {
                    self.logger.log("Credentials provided for profile \(profileID.uuidString, privacy: .public)")
                }

                let bridge = OpenVPNPacketTunnelBridge(
                    profileConfigContent: startupContext.payload.configContent,
                    profileID: profileID,
                    username: startupContext.credentials?.username,
                    password: startupContext.credentials?.password,
                    response: startupContext.otp
                )
                self.bridge = bridge

                bridge.start(
                    withPacketFlow: self.packetFlow,
                    applySettings: { [weak self] (settings: NEPacketTunnelNetworkSettings, settingsCompletion: @escaping (Error?) -> Void) in
                        guard let self else {
                            settingsCompletion(Self.unavailableError())
                            return
                        }
                        self.setTunnelNetworkSettings(settings, completionHandler: settingsCompletion)
                    },
                    completion: completionHandler
                )
            } catch {
                self.logger.error("Packet tunnel startup failed: \(error.localizedDescription, privacy: .public)")
                completionHandler(error)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.log("Packet tunnel stopped with reason: \(reason.rawValue, privacy: .public)")
        bridge?.stop()
        bridge = nil
        completionHandler()
    }

    private func resolveStartupContext(options: [String: NSObject]?) throws -> PacketTunnelStartupContext {
        guard let providerProtocol = protocolConfiguration as? NETunnelProviderProtocol else {
            throw PacketTunnelStartupError.invalidProviderPayload
        }
        return try PacketTunnelStartupContext.load(from: providerProtocol, options: options)
    }
}
