import AppKit
import Foundation
import os
import UniformTypeIdentifiers

final class MenuBarController: NSObject {
    private enum ProfileListState {
        case loaded([SystemVPNConnectionStore.VPNProfileInfo])
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
    private let credentialStore: ProfileCredentialStoring = KeychainProfileCredentialStore.shared
    private let credentialPrompt = ProfileCredentialsPrompt()
    private let profileImporter = ProfileImporter()
    private let vpnConfigurationStore = SystemVPNConfigurationStore()
    private lazy var vpnConnectionStore = SystemVPNConnectionStore(statusChangeHandler: { [weak self] profileID, state, error in
        self?.handleVPNStatusChange(profileID: profileID, state: state, disconnectError: error)
    })
    private let notifier = AppNotificationCenter.shared
    private var profileNamesByID: [UUID: String] = [:]
    private var vpnStatesByProfileID: [UUID: VPNConnectionState] = [:]
    private var disconnectingProfileIDs: Set<UUID> = []
    private let logger = Logger(subsystem: "com.macovpn.app", category: "menu-bar")

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = AppIcon.menuBarImage
            button.imagePosition = .imageOnly
            button.title = ""
        } else {
            logger.error("Status item button unavailable")
        }

        refreshMenu()
        synchronizeVPNStates()
    }

    private func refreshMenu() {
        let listing = loadProfiles()
        cacheProfiles(from: listing)
        updateStatusItem(using: status(for: listing))
        statusItem.menu = makeMenu(using: listing)
    }

    private func makeMenu(using listing: ProfileListState) -> NSMenu {
        let menu = NSMenu()
        let status = status(for: listing)

        menu.addItem(disabledItem(title: status.title))
        menu.addItem(.separator())
        menu.addItem(actionItem(title: "Import .ovpn...", action: #selector(importProfile)))
        menu.addItem(actionItem(title: "Open VPN Settings...", action: #selector(openVPNSettings)))
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
        .loaded(vpnConnectionStore.loadedProfileInfos())
    }

    private func status(for listing: ProfileListState) -> MenuBarStatus {
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

    private func updateStatusItem(using status: MenuBarStatus) {
        guard let button = statusItem.button else { return }
        button.toolTip = status.toolTip
        button.image = AppIcon.menuBarImage
    }

    private func profileMenuItem(for profile: SystemVPNConnectionStore.VPNProfileInfo) -> NSMenuItem {
        let item = NSMenuItem(title: profile.displayName, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: profile.displayName)
        let credentialState = loadCredentialState(for: profile.id)

        submenu.addItem(disabledItem(title: "Status: \(vpnState(for: profile.id).label)"))
        submenu.addItem(.separator())

        let credentialItem = actionItem(
            title: credentialState.isSaved ? "Replace Credentials..." : "Set Credentials...",
            action: #selector(editCredentials(_:))
        )
        credentialItem.representedObject = ProfileActionContext(
            id: profile.id,
            displayName: profile.displayName,
            savedUsername: credentialState.savedUsername
        )
        submenu.addItem(credentialItem)

        if credentialState.isSaved {
            let clearItem = actionItem(title: "Clear Credentials...", action: #selector(clearCredentials(_:)))
            clearItem.representedObject = ProfileActionContext(
                id: profile.id,
                displayName: profile.displayName,
                savedUsername: credentialState.savedUsername
            )
            submenu.addItem(clearItem)
        }

        submenu.addItem(.separator())

        let connectionItem = actionItem(
            title: vpnState(for: profile.id).actionTitle,
            action: #selector(toggleProfileConnection(_:))
        )
        connectionItem.isEnabled = vpnState(for: profile.id).actionEnabled
        connectionItem.representedObject = ProfileActionContext(
            id: profile.id,
            displayName: profile.displayName,
            savedUsername: credentialState.savedUsername
        )
        submenu.addItem(connectionItem)

        item.submenu = submenu
        return item
    }

    private func loadCredentialState(for profileID: UUID) -> CredentialState {
        do {
            guard let credentials = try credentialStore.loadCredentials(for: profileID) else {
                return .missing
            }
            return .saved(username: credentials.username)
        } catch {
            return .unavailable
        }
    }

    private func vpnState(for profileID: UUID) -> VPNConnectionState {
        vpnStatesByProfileID[profileID] ?? .disconnected
    }

    private func cacheProfiles(from listing: ProfileListState) {
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

            let loadedProfileInfos = self.vpnConnectionStore.loadedProfileInfos()
            self.cleanupOrphanedCredentials(validProfileIDs: Set(loadedProfileInfos.map(\.id)))
            self.refreshMenu()
        }
    }

    private func cleanupOrphanedCredentials(validProfileIDs: Set<UUID>) {
        guard let storedProfileIDs = try? credentialStore.storedProfileIDs() else {
            return
        }

        for profileID in storedProfileIDs where !validProfileIDs.contains(profileID) {
            try? credentialStore.removeCredentials(for: profileID)
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
            let contents = try profileImporter.contents(from: sourceURL)
            let analysis = try profileImporter.analyze(contents: contents, sourceFileName: sourceURL.lastPathComponent)
            let profileName = analysis.displayName

            if !analysis.warnings.isEmpty {
                let warningText = analysis.warnings
                    .map { "Line \($0.line) [\($0.directive)]: \($0.message)" }
                    .joined(separator: "\n")
                presentAlert(
                    title: "Imported \"\(profileName)\" with \(analysis.warnings.count) warning\(analysis.warnings.count == 1 ? "" : "s")",
                    message: warningText
                )
            }

            guard let credentials = credentialPrompt.prompt(profileName: profileName) else {
                return
            }

            vpnConfigurationStore.addProfile(displayName: profileName, configContent: analysis.content) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let profileID):
                    self.notifier.notifyImportSuccess(profileName: profileName, warningCount: analysis.warnings.count)
                    do {
                        try self.credentialStore.saveCredentials(credentials, for: profileID)
                        self.notifier.notifyCredentialsSaved(profileName: profileName)
                    } catch {
                        self.notifier.notifyFailure(title: "Credentials Not Saved", message: error.localizedDescription)
                        self.presentAlert(title: "Credentials Not Saved", message: error.localizedDescription)
                    }
                    self.synchronizeVPNStates()
                case .failure(let error):
                    let detail = self.detailedError(error)
                    self.notifier.notifyFailure(title: "Import Failed", message: detail)
                    self.presentAlert(title: "Import Failed", message: detail)
                }
            }
        } catch {
            let detail = detailedError(error)
            notifier.notifyFailure(title: "Import Failed", message: detail)
            presentAlert(title: "Import Failed", message: detail)
        }
    }

    @objc
    private func openVPNSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Network-Settings-Extension")!)
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

    private func disconnectProfile(with context: ProfileActionContext) {
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

    private func handleVPNStatusChange(
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
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.icon = AppIcon.applicationImage
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func detailedError(_ error: Error) -> String {
        var lines: [String] = []
        var current: Error? = error
        while let err = current {
            let ns = err as NSError
            lines.append("\(err.localizedDescription) [\(ns.domain) \(ns.code)]")
            current = ns.userInfo[NSUnderlyingErrorKey] as? Error
        }
        return lines.joined(separator: "\n↳ ")
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
