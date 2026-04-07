# Architecture Handoff — Profile Management Refactor

## Context

`maco` is a macOS menu bar VPN app using a Network Extension
(`macopackettunnel`, bundle ID `com.macovpn.app.packet-tunnel`).

Currently profiles are stored in two places:
1. On disk as `.ovpn` files in an app-managed profiles directory (via `ProfileStore`)
2. As `NETunnelProviderManager` entries in macOS System VPN preferences

This dual-store causes bugs:
- Error 3 (`missingProfileConfig`): the VPN config in System Settings stores a FILE
  PATH; if that file disappears (e.g., profile removed then re-added, path changes),
  the extension crashes on startup.
- Sync bugs: removing a profile from System Settings leaves orphaned files/keychain
  entries in maco; removing from maco may leave a stale System Settings entry.

## Goal

**Embed the `.ovpn` content directly in the `NETunnelProviderProtocol.providerConfiguration`.**
`NETunnelProviderManager` becomes the single source of truth. No files on disk needed
after import. The maco profile list comes exclusively from `NETunnelProviderManager`.

---

## Files to change

### `maco/VPN/VPNProviderPayload.swift`

Replace the file-path fields with embedded content:

```swift
struct VPNProviderPayload: Equatable, Sendable {
    static let managedByAppKey    = "macoManagedByApp"
    static let profileIDKey       = "macoProfileID"
    static let displayNameKey     = "macoDisplayName"
    static let configContentKey   = "macoConfigContent"   // NEW — full .ovpn text

    let profileID: UUID
    let displayName: String
    let configContent: String                             // NEW

    // Remove: profileDirectoryPath, profileConfigPath

    init?(providerConfiguration: [String: Any]?) {
        guard let c = providerConfiguration,
              c[Self.managedByAppKey] as? Bool == true,
              let s = c[Self.profileIDKey] as? String, let id = UUID(uuidString: s),
              let name = c[Self.displayNameKey] as? String,
              let content = c[Self.configContentKey] as? String
        else { return nil }
        self.profileID = id; self.displayName = name; self.configContent = content
    }

    var providerConfiguration: [String: Any] {
        [ Self.managedByAppKey: true,
          Self.profileIDKey: profileID.uuidString,
          Self.displayNameKey: displayName,
          Self.configContentKey: configContent ]
    }
}
```

---

### `maco/VPN/SystemVPNConfigurationStore.swift`

Remove all `ProfileRecord` / `ProfilePaths` dependencies. Replace `reconcile(profiles:)` with two simpler methods:

```swift
// Add a brand-new VPN profile from imported .ovpn content.
func addProfile(displayName: String, configContent: String,
                completion: @escaping (Result<UUID, Error>) -> Void)

// Remove the VPN configuration for a given profile ID.
func removeProfile(id: UUID, completion: @escaping (Result<Void, Error>) -> Void)
```

`addProfile` should:
1. Generate a new `UUID` for the profile.
2. Create a `VPNProviderPayload` with `displayName` and `configContent`.
3. Build an `NETunnelProviderManager`, set `providerConfiguration`, save to preferences.
4. Return the new UUID on success.

`removeProfile` should:
1. Load all preferences.
2. Find the manager whose payload has the matching `profileID`.
3. Call `removeFromPreferences`.

The old `reconcile`, `needsUpdate`, `createManager`, `configure`, `payload(for profile:)`, and all `ProfileRecord`/`ProfilePaths` references can be deleted.

---

### `macopackettunnel/PacketTunnelStartupContext.swift`

Remove all file I/O. The context is now loaded entirely from `providerConfiguration`:

```swift
struct PacketTunnelStartupContext {
    let payload: VPNProviderPayload
    let profileConfigData: Data        // derived from payload.configContent
    let credentials: ProfileCredentials?
    let otp: String?

    static func load(from providerProtocol: NETunnelProviderProtocol,
                     options: [String: NSObject]? = nil) throws -> Self {
        guard let payload = VPNProviderPayload(
                providerConfiguration: providerProtocol.providerConfiguration)
        else { throw PacketTunnelStartupError.invalidProviderPayload }

        guard let data = payload.configContent.data(using: .utf8)
        else { throw PacketTunnelStartupError.invalidProviderPayload }

        var credentials: ProfileCredentials?
        if let u = options?["username"] as? String,
           let p = options?["password"] as? String {
            credentials = ProfileCredentials(username: u, password: p)
        }
        if requiresSavedCredentials(in: data), credentials == nil {
            throw PacketTunnelStartupError.missingSavedCredentials(payload.profileID)
        }

        let otp = options?["otp"] as? String
        return PacketTunnelStartupContext(
            payload: payload, profileConfigData: data,
            credentials: credentials,
            otp: otp?.isEmpty == false ? otp : nil)
    }

    // requiresSavedCredentials stays the same (parses auth-user-pass directive)
}
```

Remove error cases: `missingProfileDirectory`, `missingProfileConfig`, `unreadableProfileConfig`.

---

### `macopackettunnel/OpenVPNPacketTunnelBridge.h`

Replace `profileConfigURL` with `profileConfigContent`:

```objc
- (instancetype)initWithProfileConfigContent:(NSString *)profileConfigContent
                                   profileID:(NSUUID *)profileID
                                    username:(nullable NSString *)username
                                    password:(nullable NSString *)password
                                    response:(nullable NSString *)response;
```

---

### `macopackettunnel/OpenVPNPacketTunnelBridge.mm`

In `PacketTunnelOpenVPNClient::start()`, instead of:
```cpp
NSString *content = [NSString stringWithContentsOfURL:profileConfigURL_ ...];
```
Use:
```cpp
NSString *content = profileConfigContent_;   // already a string, no file I/O
```

Update the ivar, init, and the bridge `@implementation` init method to match.

---

### `macopackettunnel/PacketTunnelProvider.swift`

Update bridge construction:
```swift
let bridge = OpenVPNPacketTunnelBridge(
    profileConfigContent: startupContext.payload.configContent,
    profileID: startupContext.payload.profileID,
    username: startupContext.credentials?.username,
    password: startupContext.credentials?.password,
    response: startupContext.otp
)
```

---

### `maco/VPN/SystemVPNConnectionStore.swift`

Add a method to expose loaded profile metadata (used by the menu):

```swift
struct VPNProfileInfo {
    let id: UUID
    let displayName: String
}

// After synchronize() completes, this returns the list of managed profiles.
func loadedProfileInfos() -> [VPNProfileInfo] {
    managersByProfileID.compactMap { (id, manager) in
        guard let proto = manager.protocolConfiguration as? NETunnelProviderProtocol,
              let payload = VPNProviderPayload(
                  providerConfiguration: proto.providerConfiguration)
        else { return nil }
        return VPNProfileInfo(id: id, displayName: payload.displayName)
    }
}
```

---

### `maco/App/MenuBarController.swift`

**Remove:**
- `store: ProfileStore`
- `reconcileVPNConfigurations(with:)` and its call site
- All `ProfileRecord`-based profile loading
- "Remove Profile" menu item and action
- Profile detail rows (source file name, import date, warnings in menu)

**Add:**
- `openVPNSettings()` — `@objc` action that opens System Preferences to the VPN pane:
  ```swift
  NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Network-Settings-Extension")!)
  ```
- Orphaned credential cleanup in `synchronizeVPNStates()`:
  after sync completes, get the current set of profile IDs from
  `vpnConnectionStore.loadedProfileInfos()`; compare to keychain IDs;
  remove entries for IDs that no longer exist.

**Menu structure (new):**
```
⦼ maco — N profiles          [disabled]
---
Import .ovpn...
Open VPN Settings...
---
Profiles                     [disabled header]
  [Profile Name]  →
    Status: Connected
    ---
    Set Credentials...  /  Replace Credentials...
    Clear Credentials...   (only if saved)
    ---
    Connect  /  Disconnect
---
Quit maco
```

The profile list is built from `vpnConnectionStore.loadedProfileInfos()` after sync,
not from `ProfileStore`. Profile IDs are stable (stored in providerConfiguration).

---

### Files to DELETE

- `maco/Profiles/ProfileStore.swift`
- `maco/Profiles/ProfileRecord.swift`
- `maco/Profiles/ProfilePaths.swift`
- `maco/Resources/AppIcon 2.icns` (duplicate; `AppIcon.icns` is the canonical resource now)

Keep (still used):
- `maco/Profiles/ProfileImporter.swift` — used at import time to parse display name
  and detect `auth-user-pass`. Add a method that returns `(displayName: String, content: String, warnings: [ProfileImportWarning])`.
- `maco/Profiles/ProfileImportWarning.swift` — used at import time to show warnings alert.

## Outcome

This refactor has been implemented and validated:

- `NETunnelProviderManager` is now the sole source of truth for imported profiles.
- The packet tunnel reads embedded `.ovpn` content from `providerConfiguration`.
- The menu bar shows `Connecting` immediately when a connection starts.
- The extension bundle carries the app icon so VPN entries in System Settings can display it, using `AppIcon.icns` as the canonical resource.
- A fresh build and reconnect completed successfully after the changes.

---

## Import flow (new, end-to-end)

1. User clicks "Import .ovpn..." in maco menu.
2. `NSOpenPanel` opens; user picks a `.ovpn` file.
3. Read raw file content as `String`.
4. Pass to `ProfileImporter` to get `displayName` and `warnings`.
5. Show warnings alert if any.
6. Prompt for credentials (`ProfileCredentialsPrompt.prompt`).
7. Call `vpnConfigurationStore.addProfile(displayName:configContent:)`.
   - This creates and saves a new `NETunnelProviderManager`.
   - Returns the new `profileID: UUID`.
8. Save credentials to Keychain keyed by that `UUID`.
9. Call `refreshMenu()` — loads managers from preferences, rebuilds menu.

---

## Credential management (unchanged)

- `KeychainProfileCredentialStore` stays as-is.
- `ProfileCredentials` stays as-is.
- Keychain entries are still keyed by `profile.id` (UUID).
- When a profile is removed from System Settings and maco detects it during sync,
  call `credentialStore.removeCredentials(for: id)` to clean up.

---

## Migration note

Existing VPN configurations in System Settings use the OLD payload format (file paths,
no `configContentKey`). `VPNProviderPayload.init?(providerConfiguration:)` will fail
to parse them → they won't appear in maco's menu. The user will need to:
1. Remove the old VPN entry from System Settings (or maco will ignore it).
2. Re-import the `.ovpn` profile in maco.

Consider showing a one-time alert at launch if there are un-parseable managed
configurations, telling the user to re-import.

---

## Known remaining issue: tunnel timeout

After the static-linking fix the extension starts correctly, but the VPN negotiation
times out after 120s. Next debugging step:

1. Open Console.app, filter: subsystem `com.macovpn.app.packet-tunnel`, category `OpenVPN`.
2. Attempt a connection and collect all `log:` and `event:` lines.
3. Look for: AUTH_FAILED events, TLS handshake errors, or the last log line before
   timeout — this will identify whether the issue is credentials, cert validation,
   or server connectivity.

The `static-challenge` directive in the profile means the server expects a TOTP code.
The code is passed via `creds.response` in `ClientAPI::ProvideCreds` (already implemented).
If the server is rejecting auth, it may be because the TOTP format is wrong or credentials
are stale — try re-entering credentials and connecting again.

## Implementation note

The embedded-config refactor described above has been implemented in the codebase.
The retired file-backed profile store types were deleted, the menu now sources profiles
from `NETunnelProviderManager`, and the packet tunnel startup path reads the embedded
`.ovpn` content from `providerConfiguration`.

Verification in this session was limited to repository-wide reference checks; a full
Xcode build was not run here.
