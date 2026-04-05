import AppKit

final class ProfileCredentialsPrompt {
    func prompt(profileName: String, existingUsername: String? = nil) -> ProfileCredentials? {
        let form = CredentialForm(existingUsername: existingUsername)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = existingUsername == nil
            ? "Save credentials for \(profileName)?"
            : "Update credentials for \(profileName)?"
        alert.informativeText = "Username and password are stored in Keychain. TOTP is never saved."
        alert.accessoryView = form.accessoryView
        alert.addButton(withTitle: existingUsername == nil ? "Save" : "Update")
        alert.addButton(withTitle: "Cancel")

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

    private func presentValidationAlert() {
        let alert = NSAlert()
        alert.alertStyle = .warning
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
