import AppKit

extension MenuBarController {
    func makeMenu(using listing: ProfileListState) -> NSMenu {
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

    func profileMenuItem(for profile: SystemVPNConnectionStore.VPNProfileInfo) -> NSMenuItem {
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
