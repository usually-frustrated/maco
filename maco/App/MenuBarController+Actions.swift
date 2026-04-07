import AppKit
import Foundation
import UniformTypeIdentifiers

extension MenuBarController {
    @objc
    func importProfile() {
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
            let analysis = try profileImporter.analyze(fileURL: sourceURL)
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
                        self.notifyAndAlert(title: "Credentials Not Saved", message: error.localizedDescription)
                    }
                    self.synchronizeVPNStates()
                case .failure(let error):
                    self.notifyAndAlert(title: "Import Failed", message: self.detailedError(error))
                }
            }
        } catch {
            notifyAndAlert(title: "Import Failed", message: detailedError(error))
        }
    }

    @objc
    func openVPNSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Network-Settings-Extension")!)
    }

    @objc
    func editCredentials(_ sender: NSMenuItem) {
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
            notifyAndAlert(title: "Credentials Not Saved", message: error.localizedDescription)
        }
    }

    @objc
    func clearCredentials(_ sender: NSMenuItem) {
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
            notifyAndAlert(title: "Could Not Clear Credentials", message: error.localizedDescription)
        }
    }

    @objc
    func showLogs() {
        // Opens Terminal running `log stream` filtered to this app's os_log subsystem.
        // Shows live logs from the current session for both the app and the tunnel extension.
        let script = #"""
        tell application "Terminal"
            activate
            do script "log stream --predicate 'subsystem BEGINSWITH \"com.macovpn.app\"' --level debug"
        end tell
        """#
        NSAppleScript(source: script)?.executeAndReturnError(nil)
    }

    @objc
    func quit() {
        NSApp.terminate(nil)
    }
}
