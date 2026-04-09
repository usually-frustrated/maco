import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppIcon.installAsApplicationIcon()
        installEditMenu()
        AppNotificationCenter.shared.prepare()
        SystemExtensionActivator.shared.activate()
        menuBarController = MenuBarController()
    }

    /// Without a main menu containing an Edit menu, macOS never routes
    /// standard keyboard shortcuts (⌘V/C/X/Z/A) through the responder
    /// chain to text fields inside NSAlert sheets. This installs the
    /// minimum required menu so those shortcuts work in all dialogs.
    private func installEditMenu() {
        let mainMenu = NSMenu()

        // macOS requires the first item to be the application menu.
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        appItem.submenu = NSMenu()

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editItem.submenu = editMenu

        editMenu.addItem(withTitle: "Undo",       action: Selector(("undo:")),                keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo",       action: Selector(("redo:")),                keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut",        action: #selector(NSText.cut(_:)),          keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy",       action: #selector(NSText.copy(_:)),         keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste",      action: #selector(NSText.paste(_:)),        keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)),    keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
