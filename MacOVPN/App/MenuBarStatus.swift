import Foundation

enum MenuBarStatus {
    case empty
    case ready(profileCount: Int, warningCount: Int, connectedCount: Int, busyCount: Int)
    case storageUnavailable

    var title: String {
        switch self {
        case .empty:
            return "No imported profiles yet"
        case .ready(let profileCount, _, let connectedCount, let busyCount):
            var title = "\(profileCount) imported profile\(profileCount == 1 ? "" : "s")"
            if connectedCount > 0 {
                title += " · \(connectedCount) connected"
            }
            if busyCount > 0 {
                title += " · \(busyCount) changing"
            }
            return title
        case .storageUnavailable:
            return "Profile storage unavailable"
        }
    }

    var symbolName: String {
        switch self {
        case .empty:
            return "tray"
        case .ready(_, _, let connectedCount, let busyCount):
            if connectedCount > 0 || busyCount > 0 {
                return "network"
            }
            return "lock.shield"
        case .storageUnavailable:
            return "exclamationmark.triangle"
        }
    }

    var toolTip: String {
        switch self {
        case .empty:
            return "MacOVPN · No imported profiles yet"
        case .ready(let profileCount, let warningCount, let connectedCount, let busyCount):
            var components = ["\(profileCount) imported profile\(profileCount == 1 ? "" : "s")"]
            if connectedCount > 0 {
                components.append("\(connectedCount) connected")
            }
            if busyCount > 0 {
                components.append("\(busyCount) changing")
            }
            if warningCount > 0 {
                components.append("\(warningCount) warning\(warningCount == 1 ? "" : "s")")
            }
            return "MacOVPN · \(components.joined(separator: " · "))"
        case .storageUnavailable:
            return "MacOVPN · Profile storage unavailable"
        }
    }

    static func status(profileCount: Int, warningCount: Int, connectedCount: Int, busyCount: Int) -> MenuBarStatus {
        profileCount == 0 ? .empty : .ready(
            profileCount: profileCount,
            warningCount: warningCount,
            connectedCount: connectedCount,
            busyCount: busyCount
        )
    }
}
