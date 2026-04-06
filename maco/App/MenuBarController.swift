import AppKit
import Foundation
import os
import UniformTypeIdentifiers

final class MenuBarController: NSObject {
    private enum ProfileListState {
        case loaded([ProfileRecord])
        case failed(String)
    }

    private enum CredentialState {
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

    private let statusItem: NSStatusItem
    private let store = ProfileStore.shared
    private let credentialStore: ProfileCredentialStoring = KeychainProfileCredentialStore.shared
    private let credentialPrompt = ProfileCredentialsPrompt()
    private let vpnConfigurationStore = SystemVPNConfigurationStore()
    private lazy var vpnConnectionStore = SystemVPNConnectionStore(statusChangeHandler: { [weak self] profileID, state, errorMessage in
        self?.handleVPNStatusChange(profileID: profileID, state: state, disconnectErrorMessage: errorMessage)
    })
    private let notifier = AppNotificationCenter.shared
    private var profileNamesByID: [UUID: String] = [:]
    private var vpnStatesByProfileID: [UUID: VPNConnectionState] = [:]
    private var disconnectingProfileIDs: Set<UUID> = []
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    private let logger = Logger(subsystem: "com.macovpn.app", category: "menu-bar")

    override init() {
        print("DEBUG: MenuBarController is initializing...")
        logger.info("MenuBarController init start")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
        logger.info("MenuBarController init complete")
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            logger.info("Status item button available")
            button.title = "maco"
            button.image = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: "maco")
            button.imagePosition = .imageLeading
        } else {
            logger.error("Status item button unavailable")
        }

        refreshMenu()
    }

    private func refreshMenu() {
        logger.info("Refreshing menu")
        let listing = loadProfiles()
        cacheProfiles(from: listing)
        let status = status(for: listing)
        updateStatusItem(using: status)

        if case .loaded(let profiles) = listing {
            reconcileVPNConfigurations(with: profiles)
        }

        statusItem.menu = makeMenu(using: listing)
    }

    private func makeMenu(using listing: ProfileListState) -> NSMenu {
        let menu = NSMenu()
        let status = status(for: listing)

        menu.addItem(disabledItem(title: status.title))
        menu.addItem(.separator())
        menu.addItem(actionItem(title: "Import .ovpn...", action: #selector(importProfile)))
        menu.addItem(actionItem(title: "Open Profiles Folder", action: #selector(openProfilesFolder)))
        menu.addItem(.separator())
        menu.addItem(disabledItem(title: "Profiles"))

        switch listing {
        case .loaded(let profiles) where profiles.isEmpty:
            menu.addItem(disabledItem(title: "No imported profiles yet"))
        case .loaded(let profiles):
            for profile in profiles {
                menu.addItem(profileMenuItem(for: profile))
            }
        case .failed(let message):
            menu.addItem(disabledItem(title: message))
        }

        menu.addItem(.separator())
        menu.addItem(actionItem(title: "Quit maco", action: #selector(quit)))
        return menu
    }

    private func loadProfiles() -> ProfileListState {
        do {
            return .loaded(try store.listProfiles())
        } catch {
            return .failed("Could not load profiles")
        }
    }

    private func reconcileVPNConfigurations(with profiles: [ProfileRecord]) {
        vpnConfigurationStore.reconcile(profiles: profiles) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.synchronizeVPNStates()
            case .failure(let error):
                self.notifier.notifyFailure(
                    title: "VPN Configuration Sync Failed",
                    message: error.localizedDescription
                )
            }
        }
    }

    private func status(for listing: ProfileListState) -> MenuBarStatus {
        switch listing {
        case .loaded(let profiles):
            let warningCount = profiles.reduce(into: 0) { $0 += $1.warnings.count }
            let activeStates = profiles.map { vpnState(for: $0.id) }
            let connectedCount = activeStates.filter { $0.isConnected }.count
            let busyCount = activeStates.filter { $0.isBusy }.count
            return .status(
                profileCount: profiles.count,
                warningCount: warningCount,
                connectedCount: connectedCount,
                busyCount: busyCount
            )
        case .failed:
            return .storageUnavailable
        }
    }

    private func updateStatusItem(using status: MenuBarStatus) {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: status.symbolName, accessibilityDescription: "maco")
        button.toolTip = status.toolTip
    }

    private func profileMenuItem(for profile: ProfileRecord) -> NSMenuItem {
        let item = NSMenuItem(title: profile.displayName, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: profile.displayName)
        let credentialState = loadCredentialState(for: profile)

        submenu.addItem(disabledItem(title: profile.sourceFileName))
        submenu.addItem(disabledItem(title: "Imported \(dateFormatter.string(from: profile.importedAt))"))
        submenu.addItem(disabledItem(title: warningSummary(for: profile)))
        submenu.addItem(disabledItem(title: credentialSummary(for: credentialState)))
        submenu.addItem(disabledItem(title: connectionSummary(for: profile)))
        submenu.addItem(.separator())

        let credentialItem = actionItem(
            title: credentialState.isSaved ? "Replace Credentials…" : "Set Saved Credentials…",
            action: #selector(editCredentials(_:))
        )
        credentialItem.representedObject = ProfileActionContext(
            id: profile.id,
            displayName: profile.displayName,
            savedUsername: credentialState.savedUsername
        )
        submenu.addItem(credentialItem)

        if credentialState.isSaved {
            let clearItem = actionItem(title: "Clear Saved Credentials…", action: #selector(clearCredentials(_:)))
            clearItem.representedObject = ProfileActionContext(
                id: profile.id,
                displayName: profile.displayName,
                savedUsername: credentialState.savedUsername
            )
            submenu.addItem(clearItem)
        }

        submenu.addItem(.separator())

        let connectionState = vpnState(for: profile.id)
        let connectionItem = actionItem(
            title: connectionState.actionTitle,
            action: #selector(toggleProfileConnection(_:))
        )
        connectionItem.isEnabled = connectionState.actionEnabled
        connectionItem.representedObject = ProfileActionContext(
            id: profile.id,
            displayName: profile.displayName,
            savedUsername: credentialState.savedUsername
        )
        submenu.addItem(connectionItem)

        let removeItem = actionItem(title: "Remove Profile…", action: #selector(removeProfile(_:)))
        removeItem.representedObject = ProfileActionContext(
            id: profile.id,
            displayName: profile.displayName,
            savedUsername: credentialState.savedUsername
        )
        submenu.addItem(removeItem)

        item.submenu = submenu
        return item
    }

    private func loadCredentialState(for profile: ProfileRecord) -> CredentialState {
        do {
            guard let credentials = try credentialStore.loadCredentials(for: profile.id) else {
                return .missing
            }
            return .saved(username: credentials.username)
        } catch {
            return .unavailable
        }
    }

    private func credentialSummary(for state: CredentialState) -> String {
        switch state {
        case .unavailable:
            return "Saved credentials unavailable"
        case .missing:
            return "No saved credentials"
        case .saved(let username):
            return "Saved credentials: \(username)"
        }
    }

    private func warningSummary(for profile: ProfileRecord) -> String {
        guard !profile.warnings.isEmpty else { return "No import warnings" }
        return "\(profile.warnings.count) import warning\(profile.warnings.count == 1 ? "" : "s")"
    }

    private func connectionSummary(for profile: ProfileRecord) -> String {
        "Status: \(vpnState(for: profile.id).label)"
    }

    private func vpnState(for profileID: UUID) -> VPNConnectionState {
        vpnStatesByProfileID[profileID] ?? .disconnected
    }

    private func cacheProfiles(from listing: ProfileListState) {
        switch listing {
        case .loaded(let profiles):
            profileNamesByID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0.displayName) })
            vpnStatesByProfileID = profiles.reduce(into: [:]) { result, profile in
                result[profile.id] = vpnStatesByProfileID[profile.id] ?? .disconnected
            }
        case .failed:
            profileNamesByID.removeAll()
            vpnStatesByProfileID.removeAll()
        }
    }

    private func synchronizeVPNStates() {
        vpnConnectionStore.synchronize { [weak self] result in
            guard let self else { return }
            if case .failure(let error) = result {
                self.notifier.notifyFailure(
                    title: "VPN State Sync Failed",
                    message: error.localizedDescription
                )
                return
            }

            self.refreshCachedVPNStates()
            self.renderMenu()
        }
    }

    private func refreshCachedVPNStates() {
        guard case .loaded(let profiles) = loadProfiles() else { return }
        vpnStatesByProfileID = profiles.reduce(into: [:]) { result, profile in
            result[profile.id] = vpnConnectionStore.connectionState(for: profile.id) ?? .disconnected
        }
    }

    private func disabledItem(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func renderMenu() {
        let listing = loadProfiles()
        statusItem.menu = makeMenu(using: listing)
        updateStatusItem(using: status(for: listing))
    }

    @objc
    private func importProfile() {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        if let ovpnType = UTType(filenameExtension: "ovpn") {
            panel.allowedContentTypes = [ovpnType]
        }
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Select an .ovpn profile to import"

        guard panel.runModal() == .OK, let sourceURL = panel.url else {
            return
        }

        do {
            let result = try store.importProfile(from: sourceURL)
            notifier.notifyImportSuccess(
                profileName: result.record.displayName,
                warningCount: result.warnings.count
            )
            promptForCredentialsIfNeeded(for: result.record)
            refreshMenu()
        } catch {
            notifier.notifyFailure(title: "Import Failed", message: error.localizedDescription)
            presentAlert(title: "Import Failed", message: error.localizedDescription)
        }
    }

    private func promptForCredentialsIfNeeded(for profile: ProfileRecord) {
        guard let credentials = credentialPrompt.prompt(profileName: profile.displayName) else {
            return
        }

        do {
            try credentialStore.saveCredentials(credentials, for: profile.id)
            notifier.notifyCredentialsSaved(profileName: profile.displayName)
        } catch {
            notifier.notifyFailure(title: "Credentials Not Saved", message: error.localizedDescription)
            presentAlert(title: "Credentials Not Saved", message: error.localizedDescription)
        }
    }

    @objc
    private func openProfilesFolder() {
        if !store.openProfilesFolder() {
            notifier.notifyFailure(title: "Could Not Open Folder", message: store.profilesFolderURL.path)
            presentAlert(title: "Could Not Open Folder", message: store.profilesFolderURL.path)
        }
    }

    @objc
    private func removeProfile(_ sender: NSMenuItem) {
        guard let context = sender.representedObject as? ProfileActionContext else {
            return
        }

        guard confirmRemoval(for: context.displayName) else {
            return
        }

        do {
            try credentialStore.removeCredentials(for: context.id)
            try store.removeProfile(id: context.id)
            disconnectingProfileIDs.remove(context.id)
            vpnStatesByProfileID.removeValue(forKey: context.id)
            profileNamesByID.removeValue(forKey: context.id)
            notifier.notifyRemoval(profileName: context.displayName)
            refreshMenu()
        } catch {
            notifier.notifyFailure(title: "Remove Failed", message: error.localizedDescription)
            presentAlert(title: "Remove Failed", message: error.localizedDescription)
        }
    }

    @objc
    private func editCredentials(_ sender: NSMenuItem) {
        guard let context = sender.representedObject as? ProfileActionContext else {
            return
        }

        guard let credentials = credentialPrompt.prompt(
            profileName: context.displayName,
            existingUsername: context.savedUsername
        ) else {
            return
        }

        do {
            try credentialStore.saveCredentials(credentials, for: context.id)
            notifier.notifyCredentialsSaved(profileName: context.displayName)
            refreshMenu()
        } catch {
            notifier.notifyFailure(title: "Credentials Not Saved", message: error.localizedDescription)
            presentAlert(title: "Credentials Not Saved", message: error.localizedDescription)
        }
    }

    @objc
    private func clearCredentials(_ sender: NSMenuItem) {
        guard let context = sender.representedObject as? ProfileActionContext else {
            return
        }

        guard confirmCredentialClear(for: context.displayName) else {
            return
        }

        do {
            try credentialStore.removeCredentials(for: context.id)
            notifier.notifyCredentialsCleared(profileName: context.displayName)
            refreshMenu()
        } catch {
            notifier.notifyFailure(title: "Could Not Clear Credentials", message: error.localizedDescription)
            presentAlert(title: "Could Not Clear Credentials", message: error.localizedDescription)
        }
    }

    @objc
    private func toggleProfileConnection(_ sender: NSMenuItem) {
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

    private func connectProfile(with context: ProfileActionContext) {
        vpnConnectionStore.connect(profileID: context.id) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.vpnStatesByProfileID[context.id] = .connecting
                self.renderMenu()
            case .failure(let error):
                self.vpnStatesByProfileID[context.id] = .failed(error.localizedDescription)
                self.notifier.notifyVPNFailed(profileName: context.displayName, message: error.localizedDescription)
                self.presentAlert(title: "VPN Connect Failed", message: error.localizedDescription)
                self.renderMenu()
            }
        }
    }

    private func disconnectProfile(with context: ProfileActionContext) {
        disconnectingProfileIDs.insert(context.id)
        vpnConnectionStore.disconnect(profileID: context.id) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.vpnStatesByProfileID[context.id] = .disconnecting
                self.renderMenu()
            case .failure(let error):
                self.disconnectingProfileIDs.remove(context.id)
                self.vpnStatesByProfileID[context.id] = .failed(error.localizedDescription)
                self.notifier.notifyVPNFailed(profileName: context.displayName, message: error.localizedDescription)
                self.presentAlert(title: "VPN Disconnect Failed", message: error.localizedDescription)
                self.renderMenu()
            }
        }
    }

    private func handleVPNStatusChange(
        profileID: UUID,
        state: VPNConnectionState,
        disconnectErrorMessage: String?
    ) {
        let previousState = vpnStatesByProfileID[profileID] ?? .disconnected
        vpnStatesByProfileID[profileID] = state
        guard let profileName = profileNamesByID[profileID] else {
            renderMenu()
            return
        }

        guard previousState != state else {
            renderMenu()
            return
        }

        switch state {
        case .connecting:
            notifier.notifyVPNConnecting(profileName: profileName)
        case .connected:
            notifier.notifyVPNConnected(profileName: profileName)
        case .disconnecting:
            notifier.notifyVPNDisconnecting(profileName: profileName)
        case .failed(let message):
            notifier.notifyVPNFailed(profileName: profileName, message: message ?? "The VPN disconnected unexpectedly.")
        case .disconnected:
            if disconnectingProfileIDs.remove(profileID) != nil {
                notifier.notifyVPNDisconnected(profileName: profileName)
            } else {
                notifier.notifyVPNDisconnected(profileName: profileName)
            }
        case .reasserting:
            notifier.notifyVPNConnecting(profileName: profileName)
        case .invalid:
            break
        }

        renderMenu()
    }

    private func confirmRemoval(for displayName: String) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Remove this profile?"
        alert.informativeText = displayName
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func confirmCredentialClear(for displayName: String) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Clear saved credentials?"
        alert.informativeText = displayName
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }
}

private final class ProfileActionContext: NSObject {
    let id: UUID
    let displayName: String
    let savedUsername: String?

    init(id: UUID, displayName: String, savedUsername: String?) {
        self.id = id
        self.displayName = displayName
        self.savedUsername = savedUsername
    }
}
