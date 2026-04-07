import AppKit
import Foundation

extension MenuBarController {
    @objc
    func toggleProfileConnection(_ sender: NSMenuItem) {
        guard let context = sender.representedObject as? ProfileActionContext else {
            return
        }

        switch vpnState(for: context.id) {
        case .connected, .connecting, .reasserting:
            disconnectProfile(with: context)
        case .disconnecting:
            return
        case .invalid, .disconnected, .failed:
            connectProfile(with: context)
        }
    }

    func connectProfile(with context: ProfileActionContext) {
        guard let otp = credentialPrompt.promptForOTP(profileName: context.displayName) else {
            return
        }

        vpnStatesByProfileID[context.id] = .connecting
        refreshMenu()

        var options: [String: NSObject] = [:]
        if let credentials = try? credentialStore.loadCredentials(for: context.id) {
            options["username"] = credentials.username as NSString
            options["password"] = credentials.password as NSString
        }
        if !otp.isEmpty {
            options["otp"] = otp as NSString
        }

        vpnConnectionStore.connect(profileID: context.id, options: options.isEmpty ? nil : options) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.refreshMenu()
            case .failure(let error):
                let detail = self.detailedError(error)
                self.vpnStatesByProfileID[context.id] = .failed(detail)
                self.notifier.notifyVPNFailed(profileName: context.displayName, message: detail)
                self.presentAlert(title: "VPN Connection Failed", message: detail)
                self.refreshMenu()
            }
        }
    }

    func disconnectProfile(with context: ProfileActionContext) {
        disconnectingProfileIDs.insert(context.id)
        vpnConnectionStore.disconnect(profileID: context.id) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.vpnStatesByProfileID[context.id] = .disconnecting
                self.refreshMenu()
            case .failure(let error):
                self.disconnectingProfileIDs.remove(context.id)
                self.vpnStatesByProfileID[context.id] = .failed(error.localizedDescription)
                self.notifier.notifyVPNFailed(profileName: context.displayName, message: error.localizedDescription)
                self.refreshMenu()
            }
        }
    }
}
