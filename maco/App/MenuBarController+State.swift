import AppKit
import Foundation

extension MenuBarController {
    func loadCredentialState(for profileID: UUID) -> CredentialState {
        do {
            guard let credentials = try credentialStore.loadCredentials(for: profileID) else {
                return .missing
            }
            return .saved(username: credentials.username)
        } catch {
            return .unavailable
        }
    }

    func vpnState(for profileID: UUID) -> VPNConnectionState {
        vpnStatesByProfileID[profileID] ?? .disconnected
    }

    func cacheProfiles(from listing: ProfileListState) {
        switch listing {
        case .loaded(let profiles):
            profileNamesByID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0.displayName) })
            vpnStatesByProfileID = profiles.reduce(into: [:]) { result, profile in
                result[profile.id] = vpnConnectionStore.connectionState(for: profile.id) ?? .disconnected
            }
        case .failed:
            profileNamesByID.removeAll()
            vpnStatesByProfileID.removeAll()
        }
    }

    func synchronizeVPNStates() {
        vpnConnectionStore.synchronize { [weak self] result in
            guard let self else { return }
            if case .failure(let error) = result {
                self.notifier.notifyFailure(
                    title: "VPN State Sync Failed",
                    message: error.localizedDescription
                )
                return
            }

            let loadedProfileInfos = self.vpnConnectionStore.loadedProfileInfos()
            self.cleanupOrphanedCredentials(validProfileIDs: Set(loadedProfileInfos.map(\.id)))
            self.refreshMenu()
        }
    }

    func cleanupOrphanedCredentials(validProfileIDs: Set<UUID>) {
        guard let storedProfileIDs = try? credentialStore.storedProfileIDs() else {
            return
        }

        for profileID in storedProfileIDs where !validProfileIDs.contains(profileID) {
            try? credentialStore.removeCredentials(for: profileID)
        }
    }

    func handleVPNStatusChange(
        profileID: UUID,
        state: VPNConnectionState,
        disconnectError: Error?
    ) {
        let previousState = vpnStatesByProfileID[profileID] ?? .disconnected
        vpnStatesByProfileID[profileID] = state
        guard let profileName = profileNamesByID[profileID] else {
            refreshMenu()
            return
        }

        guard previousState != state else {
            refreshMenu()
            return
        }

        switch state {
        case .connecting:
            notifier.notifyVPNConnecting(profileName: profileName)
        case .connected:
            notifier.notifyVPNConnected(profileName: profileName)
        case .disconnecting:
            notifier.notifyVPNDisconnecting(profileName: profileName)
        case .failed:
            let failureMessage = disconnectError.map { detailedError($0) }
                ?? "The VPN disconnected unexpectedly. No additional details available."
            notifier.notifyVPNFailed(profileName: profileName, message: failureMessage)
        case .disconnected:
            disconnectingProfileIDs.remove(profileID)
            notifier.notifyVPNDisconnected(profileName: profileName)
        case .reasserting:
            notifier.notifyVPNConnecting(profileName: profileName)
        case .invalid:
            break
        }

        refreshMenu()
    }

    func confirmCredentialClear(for displayName: String) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Clear saved credentials?"
        alert.informativeText = displayName
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    func presentAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.icon = AppIcon.applicationImage
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func detailedError(_ error: Error) -> String {
        var lines: [String] = []
        var current: Error? = error
        while let err = current {
            let ns = err as NSError
            lines.append("\(err.localizedDescription) [\(ns.domain) \(ns.code)]")
            current = ns.userInfo[NSUnderlyingErrorKey] as? Error
        }
        return lines.joined(separator: "\n↳ ")
    }
}
