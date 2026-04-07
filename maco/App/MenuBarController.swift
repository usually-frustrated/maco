import AppKit
import Foundation
import os

final class MenuBarController: NSObject {
    enum ProfileListState {
        case loaded([SystemVPNConnectionStore.VPNProfileInfo])
        case failed(String)
    }

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
    static let menuBarTitle = " ⦼ "

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
    }

    func configureStatusItem() {
        if let button = statusItem.button {
            button.image = nil
            button.imagePosition = .noImage
            button.title = Self.menuBarTitle
        } else {
            logger.error("Status item button unavailable")
        }

        refreshMenu()
        synchronizeVPNStates()
    }

    func refreshMenu() {
        let listing = loadProfiles()
        cacheProfiles(from: listing)
        updateStatusItem(using: status(for: listing))
        statusItem.menu = makeMenu(using: listing)
    }

    func loadProfiles() -> ProfileListState {
        .loaded(vpnConnectionStore.loadedProfileInfos())
    }

    func status(for listing: ProfileListState) -> MenuBarStatus {
        switch listing {
        case .loaded(let profiles):
            let activeStates = profiles.map { vpnState(for: $0.id) }
            let connectedCount = activeStates.filter { $0.isConnected }.count
            let busyCount = activeStates.filter { $0.isBusy }.count
            return .status(
                profileCount: profiles.count,
                connectedCount: connectedCount,
                busyCount: busyCount
            )
        case .failed:
            return .storageUnavailable
        }
    }

    func updateStatusItem(using status: MenuBarStatus) {
        guard let button = statusItem.button else { return }
        button.toolTip = status.toolTip
        button.image = nil
        button.imagePosition = .noImage
        button.title = Self.menuBarTitle
    }
}
