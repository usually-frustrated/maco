import AppKit
import Foundation
import os

final class MenuBarController: NSObject {
    enum CredentialState {
        case unavailable
        case missing
        case saved(username: String)

        var isSaved: Bool {
            if case .saved = self { return true }
            return false
        }

        var savedUsername: String? {
            if case .saved(let username) = self { return username }
            return nil
        }
    }

    let statusItem: NSStatusItem
    let credentialStore: ProfileCredentialStoring = KeychainProfileCredentialStore.shared
    let credentialPrompt = ProfileCredentialsPrompt()
    let profileImporter = ProfileImporter()
    let vpnConfigurationStore = SystemVPNConfigurationStore()
    lazy var vpnConnectionStore = SystemVPNConnectionStore(statusChangeHandler: { [weak self] profileID, state, error in
        self?.handleVPNStatusChange(profileID: profileID, state: state, disconnectError: error)
    })
    let notifier = AppNotificationCenter.shared
    var profileNamesByID: [UUID: String] = [:]
    var vpnStatesByProfileID: [UUID: VPNConnectionState] = [:]
    var disconnectingProfileIDs: Set<UUID> = []
    let logger = Logger(subsystem: "com.macovpn.app", category: "menu-bar")

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
    }

    func configureStatusItem() {
        if statusItem.button == nil {
            logger.error("Status item button unavailable")
        }
        refreshMenu()
        synchronizeVPNStates()
    }

    func refreshMenu() {
        let profiles = vpnConnectionStore.loadedProfileInfos()
        cacheProfiles(from: profiles)
        let menuStatus = status(for: profiles)
        updateStatusItem(using: menuStatus)
        statusItem.menu = makeMenu(using: profiles)
    }

    func status(for profiles: [SystemVPNConnectionStore.VPNProfileInfo]) -> MenuBarStatus {
        let activeStates = profiles.map { vpnState(for: $0.id) }
        return .status(
            profileCount: profiles.count,
            connectedCount: activeStates.filter { $0.isConnected }.count,
            busyCount: activeStates.filter { $0.isBusy }.count
        )
    }

    func updateStatusItem(using status: MenuBarStatus) {
        guard let button = statusItem.button else { return }
        button.toolTip = status.toolTip
        button.title = ""
        if let image = NSImage(systemSymbolName: status.symbolName, accessibilityDescription: nil) {
            image.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
        }
    }
}
