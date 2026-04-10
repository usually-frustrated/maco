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
            logger.info("Importing profile '\(profileName, privacy: .public)' from \(sourceURL.lastPathComponent, privacy: .public)")

            if !analysis.warnings.isEmpty {
                logger.warning("Profile '\(profileName, privacy: .public)' has \(analysis.warnings.count) warning(s)")
                let warningText = analysis.warnings
                    .map { "Line \($0.line) [\($0.directive)]: \($0.message)" }
                    .joined(separator: "\n")
                presentAlert(
                    title: "Imported \"\(profileName)\" with \(analysis.warnings.count) warning\(analysis.warnings.count == 1 ? "" : "s")",
                    message: warningText
                )
            }

            guard let credentials = credentialPrompt.prompt(profileName: profileName) else {
                logger.info("Profile import cancelled at credentials prompt for '\(profileName, privacy: .public)'")
                return
            }

            vpnConfigurationStore.addProfile(displayName: profileName, configContent: analysis.content) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let profileID):
                    self.logger.info("Profile '\(profileName, privacy: .public)' imported successfully (id: \(profileID, privacy: .public))")
                    self.notifier.notifyImportSuccess(profileName: profileName, warningCount: analysis.warnings.count)
                    do {
                        try self.credentialStore.saveCredentials(credentials, for: profileID)
                        self.notifier.notifyCredentialsSaved(profileName: profileName)
                    } catch {
                        self.logger.error("Failed to save credentials for '\(profileName, privacy: .public)': \(error.localizedDescription, privacy: .public)")
                        self.notifyAndAlert(title: "Credentials Not Saved", message: error.localizedDescription)
                    }
                    self.synchronizeVPNStates()
                case .failure(let error):
                    self.logger.error("Profile import failed for '\(profileName, privacy: .public)': \(self.detailedError(error), privacy: .public)")
                    self.notifyAndAlert(title: "Import Failed", message: self.detailedError(error))
                }
            }
        } catch {
            logger.error("Profile analysis failed for \(sourceURL.lastPathComponent, privacy: .public): \(self.detailedError(error), privacy: .public)")
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
            logger.info("Credentials updated for profile '\(context.displayName, privacy: .public)'")
            notifier.notifyCredentialsSaved(profileName: context.displayName)
            refreshMenu()
        } catch {
            logger.error("Failed to save credentials for '\(context.displayName, privacy: .public)': \(error.localizedDescription, privacy: .public)")
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
            logger.info("Credentials cleared for profile '\(context.displayName, privacy: .public)'")
            notifier.notifyCredentialsCleared(profileName: context.displayName)
            refreshMenu()
        } catch {
            logger.error("Failed to clear credentials for '\(context.displayName, privacy: .public)': \(error.localizedDescription, privacy: .public)")
            notifyAndAlert(title: "Could Not Clear Credentials", message: error.localizedDescription)
        }
    }

    @objc
    func showLogs() {
        if logViewerWindowController == nil {
            logViewerWindowController = LogViewerWindowController()
        }
        NSApp.activate(ignoringOtherApps: true)
        logViewerWindowController?.showWindow(nil)
    }

    @objc
    func quit() {
        NSApp.terminate(nil)
    }
}
