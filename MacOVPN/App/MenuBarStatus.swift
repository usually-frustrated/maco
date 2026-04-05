import Foundation

enum MenuBarStatus {
    case empty
    case ready(profileCount: Int, warningCount: Int)
    case storageUnavailable

    var title: String {
        switch self {
        case .empty:
            return "No imported profiles yet"
        case .ready(let profileCount, _):
            return "\(profileCount) imported profile\(profileCount == 1 ? "" : "s")"
        case .storageUnavailable:
            return "Profile storage unavailable"
        }
    }

    var symbolName: String {
        switch self {
        case .empty:
            return "tray"
        case .ready:
            return "lock.shield"
        case .storageUnavailable:
            return "exclamationmark.triangle"
        }
    }

    var toolTip: String {
        switch self {
        case .empty:
            return "MacOVPN · No imported profiles yet"
        case .ready(let profileCount, let warningCount):
            let profileText = "\(profileCount) imported profile\(profileCount == 1 ? "" : "s")"
            guard warningCount > 0 else {
                return "MacOVPN · \(profileText)"
            }
            return "MacOVPN · \(profileText) · \(warningCount) warning\(warningCount == 1 ? "" : "s")"
        case .storageUnavailable:
            return "MacOVPN · Profile storage unavailable"
        }
    }

    static func status(profileCount: Int, warningCount: Int) -> MenuBarStatus {
        profileCount == 0 ? .empty : .ready(profileCount: profileCount, warningCount: warningCount)
    }
}
