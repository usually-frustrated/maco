import AppKit

extension MenuBarController {
    func makeMenu(using profiles: [SystemVPNConnectionStore.VPNProfileInfo]) -> NSMenu {
        let menu = NSMenu()

        menu.addItem(disabledItem(title: status(for: profiles).title))
        menu.addItem(.separator())
        menu.addItem(actionItem(title: "Import .ovpn...", action: #selector(importProfile)))
        menu.addItem(actionItem(title: "Open VPN Settings...", action: #selector(openVPNSettings)))
        menu.addItem(actionItem(title: "Show Logs...", action: #selector(showLogs)))
        menu.addItem(.separator())
        menu.addItem(disabledItem(title: "Profiles"))

        if profiles.isEmpty {
            menu.addItem(disabledItem(title: "No imported profiles yet"))
        } else {
            for profile in profiles {
                menu.addItem(profileMenuItem(for: profile))
            }
        }

        menu.addItem(.separator())
        menu.addItem(actionItem(title: "Quit maco", action: #selector(quit)))
        return menu
    }

    func profileMenuItem(for profile: SystemVPNConnectionStore.VPNProfileInfo) -> NSMenuItem {
        let item = NSMenuItem(title: profile.displayName, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: profile.displayName)
        let credentialState = loadCredentialState(for: profile.id)
        let context = ProfileActionContext(
            id: profile.id,
            displayName: profile.displayName,
            savedUsername: credentialState.savedUsername
        )

        submenu.addItem(disabledItem(title: "Status: \(vpnState(for: profile.id).label)"))
        submenu.addItem(.separator())

        let credentialItem = actionItem(
            title: credentialState.isSaved ? "Replace Credentials..." : "Set Credentials...",
            action: #selector(editCredentials(_:))
        )
        credentialItem.representedObject = context
        submenu.addItem(credentialItem)

        if credentialState.isSaved {
            let clearItem = actionItem(title: "Clear Credentials...", action: #selector(clearCredentials(_:)))
            clearItem.representedObject = context
            submenu.addItem(clearItem)
        }

        submenu.addItem(.separator())

        let connectionItem = actionItem(
            title: vpnState(for: profile.id).actionTitle,
            action: #selector(toggleProfileConnection(_:))
        )
        connectionItem.isEnabled = vpnState(for: profile.id).actionEnabled
        connectionItem.representedObject = context
        submenu.addItem(connectionItem)

        item.submenu = submenu
        return item
    }

    func disabledItem(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    func actionItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }
}
