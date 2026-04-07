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
    var isPromptingForOTP = false
    let logger = Logger(subsystem: "frustrated.maco.app", category: "menu-bar")

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
        let imageName = isPromptingForOTP ? "MenuBarIconWaitingForOTP" : status.imageName
        if let image = NSImage(named: imageName)?.copy() as? NSImage {
            image.size = NSSize(width: 18, height: 18)
            button.image = image
            button.imagePosition = .imageOnly
        }
    }
}
