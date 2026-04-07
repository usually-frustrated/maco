import Foundation

enum MenuBarStatus {
    case empty
    case ready(profileCount: Int, connectedCount: Int, busyCount: Int)

    var imageName: String {
        switch self {
        case .empty:
            return "MenuBarIcon"
        case .ready(_, let connectedCount, let busyCount):
            if connectedCount > 0 { return "MenuBarIconConnected" }
            if busyCount > 0 { return "MenuBarIconConnecting" }
            return "MenuBarIcon"
        }
    }

    var title: String {
        switch self {
        case .empty:
            return "No imported profiles yet"
        case .ready(let profileCount, _, _):
            return "\(profileCount) imported profile\(profileCount == 1 ? "" : "s")"
        }
    }

    var toolTip: String {
        switch self {
        case .empty:
            return "maco · No imported profiles yet"
        case .ready(let profileCount, let connectedCount, let busyCount):
            var components = ["\(profileCount) imported profile\(profileCount == 1 ? "" : "s")"]
            if connectedCount > 0 { components.append("\(connectedCount) connected") }
            if busyCount > 0 { components.append("\(busyCount) changing") }
            return "maco · \(components.joined(separator: " · "))"
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
