import Foundation

enum MenuBarStatus {
    case empty
    case ready(profileCount: Int, connectedCount: Int, busyCount: Int)
    case storageUnavailable

    var title: String {
        switch self {
        case .empty:
            return "No imported profiles yet"
        case .ready(let profileCount, _, _):
            return "\(profileCount) imported profile\(profileCount == 1 ? "" : "s")"
        case .storageUnavailable:
            return "Profile storage unavailable"
        }
    }

    var symbolName: String {
        switch self {
        case .empty:
            return "tray"
        case .ready(_, let connectedCount, let busyCount):
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
            return "maco · No imported profiles yet"
        case .ready(let profileCount, let connectedCount, let busyCount):
            var components = ["\(profileCount) imported profile\(profileCount == 1 ? "" : "s")"]
            if connectedCount > 0 {
                components.append("\(connectedCount) connected")
            }
            if busyCount > 0 {
                components.append("\(busyCount) changing")
            }
            return "maco · \(components.joined(separator: " · "))"
        case .storageUnavailable:
            return "maco · Profile storage unavailable"
        }
    }

    static func status(profileCount: Int, connectedCount: Int, busyCount: Int) -> MenuBarStatus {
        profileCount == 0 ? .empty : .ready(
            profileCount: profileCount,
            connectedCount: connectedCount,
            busyCount: busyCount
        )
    }
}
