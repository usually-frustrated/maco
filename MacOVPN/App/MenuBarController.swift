import AppKit
import Foundation
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
    private let notifier = AppNotificationCenter.shared
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureStatusItem()
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: "MacOVPN")
            button.imagePosition = .imageOnly
        }

        refreshMenu()
    }

    private func refreshMenu() {
        statusItem.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let listing = loadProfiles()
        let status = status(for: listing)

        updateStatusItem(using: status)

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
        menu.addItem(actionItem(title: "Quit MacOVPN", action: #selector(quit)))
        return menu
    }

    private func loadProfiles() -> ProfileListState {
        do {
            return .loaded(try store.listProfiles())
        } catch {
            return .failed("Could not load profiles")
        }
    }

    private func status(for listing: ProfileListState) -> MenuBarStatus {
        switch listing {
        case .loaded(let profiles):
            let warningCount = profiles.reduce(into: 0) { $0 += $1.warnings.count }
            return .status(profileCount: profiles.count, warningCount: warningCount)
        case .failed:
            return .storageUnavailable
        }
    }

    private func updateStatusItem(using status: MenuBarStatus) {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: status.symbolName, accessibilityDescription: "MacOVPN")
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
