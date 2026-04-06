import NetworkExtension

enum VPNConnectionState: Equatable {
    case invalid
    case disconnected
    case failed(String?)
    case connecting
    case connected
    case reasserting
    case disconnecting

    init(status: NEVPNStatus) {
        switch status {
        case .invalid:
            self = .invalid
        case .disconnected:
            self = .disconnected
        case .connecting:
            self = .connecting
        case .connected:
            self = .connected
        case .reasserting:
            self = .reasserting
        case .disconnecting:
            self = .disconnecting
        @unknown default:
            self = .invalid
        }
    }

    var isActive: Bool {
        switch self {
        case .connected, .connecting, .reasserting, .disconnecting:
            return true
        case .invalid, .disconnected, .failed:
            return false
        }
    }

    var isConnected: Bool {
        self == .connected
    }

    var isBusy: Bool {
        switch self {
        case .connecting, .reasserting, .disconnecting:
            return true
        case .invalid, .disconnected, .failed, .connected:
            return false
        }
    }

    var label: String {
        switch self {
        case .invalid:
            return "Configuration unavailable"
        case .disconnected:
            return "Disconnected"
        case .failed(let message):
            guard let message, !message.isEmpty else {
                return "Failed"
            }
            return "Failed: \(message)"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .reasserting:
            return "Reasserting"
        case .disconnecting:
            return "Disconnecting"
        }
    }

    var actionTitle: String {
        isConnected || isBusy ? "Disconnect" : "Connect"
    }

    var actionEnabled: Bool {
        self != .invalid && self != .disconnecting
    }
}
