import UserNotifications

final class AppNotificationCenter {
    static let shared = AppNotificationCenter()

    private let center = UNUserNotificationCenter.current()

    func prepare() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notifyImportSuccess(profileName: String, warningCount: Int) {
        let message = warningCount == 0 ? "Imported from .ovpn" : "Imported with \(warningCount) warning\(warningCount == 1 ? "" : "s")"
        post(title: "Profile Imported", message: "\(profileName) · \(message)")
    }

    func notifyRemoval(profileName: String) {
        post(title: "Profile Removed", message: profileName)
    }

    func notifyCredentialsSaved(profileName: String) {
        post(title: "Credentials Saved", message: profileName)
    }

    func notifyCredentialsCleared(profileName: String) {
        post(title: "Credentials Cleared", message: profileName)
    }

    func notifyVPNConnecting(profileName: String) {
        post(title: "VPN Connecting", message: profileName)
    }

    func notifyVPNConnected(profileName: String) {
        post(title: "VPN Connected", message: profileName)
    }

    func notifyVPNDisconnecting(profileName: String) {
        post(title: "VPN Disconnecting", message: profileName)
    }

    func notifyVPNDisconnected(profileName: String) {
        post(title: "VPN Disconnected", message: profileName)
    }

    func notifyVPNFailed(profileName: String, message: String) {
        post(title: "VPN Failed", message: "\(profileName) · \(message)")
    }

    func notifyFailure(title: String, message: String) {
        post(title: title, message: message)
    }

    private func post(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request)
    }
}
