import AppKit

final class ProfileCredentialsPrompt {
    func prompt(profileName: String, existingUsername: String? = nil) -> ProfileCredentials? {
        let form = CredentialForm(existingUsername: existingUsername)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.icon = AppIcon.applicationImage
        alert.messageText = existingUsername == nil
            ? "Save credentials for \(profileName)?"
            : "Update credentials for \(profileName)?"
        alert.informativeText = "Username and password are stored in Keychain. TOTP is never saved."
        alert.accessoryView = form.accessoryView
        alert.addButton(withTitle: existingUsername == nil ? "Save" : "Update")
        alert.addButton(withTitle: "Cancel")

        activate()

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }

        let username = form.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = form.password
        guard !username.isEmpty, !password.isEmpty else {
            presentValidationAlert()
            return nil
        }

        return ProfileCredentials(username: username, password: password)
    }

    /// Shows an OTP prompt at connect time. Returns the entered code (may be empty if not
    /// required), or nil if the user cancelled the connection.
    func promptForOTP(profileName: String) -> String? {
        let field = NSTextField(string: "")
        field.placeholderString = "123456"
        field.frame = CGRect(x: 0, y: 0, width: 200, height: 24)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.icon = AppIcon.applicationImage
        alert.messageText = "One-time password for \(profileName)"
        alert.informativeText = "Enter your TOTP code, or leave blank if not required."
        alert.accessoryView = field
        alert.addButton(withTitle: "Connect")
        alert.addButton(withTitle: "Cancel")

        activate()

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }

        return field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func activate() {
        // Bring the app forward so ⌘V / ⌘C work in text fields.
        // Required because this app runs as .accessory and is not always frontmost.
        NSApp.activate(ignoringOtherApps: true)
    }

    private func presentValidationAlert() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.icon = AppIcon.applicationImage
        alert.messageText = "Username and password are required."
        alert.informativeText = "TOTP is never stored."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

private final class CredentialForm {
    let accessoryView: NSView

    private let usernameField = NSTextField(string: "")
    private let passwordField = NSSecureTextField(string: "")

    init(existingUsername: String?) {
        if let existingUsername {
            usernameField.stringValue = existingUsername
        }

        usernameField.placeholderString = "Username"
        passwordField.placeholderString = "Password"

        let usernameLabel = NSTextField(labelWithString: "Username")
        let passwordLabel = NSTextField(labelWithString: "Password")
        let grid = NSGridView(views: [
            [usernameLabel, usernameField],
            [passwordLabel, passwordField]
        ])
        grid.rowSpacing = 8
        grid.columnSpacing = 12

        let container = NSView(frame: CGRect(x: 0, y: 0, width: 360, height: 80))
        grid.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            grid.topAnchor.constraint(equalTo: container.topAnchor),
            grid.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        accessoryView = container
    }

    var username: String { usernameField.stringValue }
    var password: String { passwordField.stringValue }
}
