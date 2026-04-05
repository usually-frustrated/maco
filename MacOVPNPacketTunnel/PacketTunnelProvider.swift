import NetworkExtension
import os.log

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private let logger = Logger(subsystem: "com.macovpn.app.packet-tunnel", category: "PacketTunnel")

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        logger.log("Packet tunnel start requested before OpenVPN core integration is implemented.")
        let error = NSError(
            domain: "MacOVPN.PacketTunnel",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "OpenVPN core integration is not implemented yet."]
        )
        completionHandler(error)
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.log("Packet tunnel stopped with reason: \(reason.rawValue, privacy: .public)")
        completionHandler()
    }
}
