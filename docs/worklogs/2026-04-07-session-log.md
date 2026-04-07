# Session Log — 2026-04-07

## What we did this session

### 1. Import warnings — add recognized directives
Added `server-poll-timeout`, `dev-type`, `static-challenge`, `push-peer-info` to
`ProfileImporter.supportedDirectives`. Profiles using these directives no longer
produce spurious "not interpreted yet" warnings.

### 2. OTP / static-challenge fix
- `PacketTunnelStartupContext`: stopped appending OTP to the password string; added
  a separate `otp: String?` field on the context struct.
- `OpenVPNPacketTunnelBridge` (header + .mm): added `response:` parameter; sets
  `creds.response` in `ClientAPI::ProvideCreds` — the correct OpenVPN3 field for
  static-challenge answers, not a password concatenation.
- `PacketTunnelProvider`: passes `startupContext.otp` as `response:` to the bridge.

### 3. OpenVPN core logging
Added `os_log` to `event()` and `log()` callbacks in `OpenVPNPacketTunnelBridge.mm`.
Logs appear in Console.app under subsystem `com.macovpn.app.packet-tunnel`,
category `OpenVPN`. Also logs `connect()` return value from the worker thread.

### 4. VPN failure error surfacing
- `SystemVPNConnectionStore.StatusChangeHandler`: changed third param from
  `String?` to `Error?` so the full error chain is preserved.
- `MenuBarController.handleVPNStatusChange`: calls `detailedError(_:)` on the raw
  `Error` to get domain + code at every level.
- VPN failures from status changes show only a system notification (not a modal);
  the full error is readable in the profile submenu under "Status:".
- `presentAlert`: uses `NSApp.applicationIconImage`; reverted to `informativeText`
  (no more scrollable textarea).

### 5. Edit menu / copy-paste in dialogs
`AppDelegate.installEditMenu()` — programmatically adds a main menu with an Edit
submenu containing Cut/Copy/Paste/Select All/Undo/Redo. Without this, macOS does
not route ⌘V/C/X/Z through the responder chain in `.accessory` apps.

### 6. Menu bar icon
Changed from SF Symbol `lock.shield` to the Unicode character `⦼` rendered as the
button title at font size 16.

### 7. App icon
- Identified that `INFOPLIST_KEY_CFBundleIconFile = AppIcon` didn't match the
  bundled file (`AppIcon.icns`).
- Fixed: changed the key to `AppIcon` in project.pbxproj (both Debug and
  Release configs) and copied the icon into the extension bundle. Maco's icon
  now appears correctly in System Settings > VPN and Dock/Finder. Alerts use
  `NSApp.applicationIconImage`.

### 8. Static linking — fixed extension dyld crash
Root cause: `macopackettunnel.appex` was dynamically linked against six zerobrew
libraries. The Network Extension sandbox blocks access to `/opt/zerobrew/` at
runtime → immediate dyld crash (error code `NEVPNConnectionErrorDomain 12` /
`pluginFailed`).

Fix: switched ALL zerobrew dependencies to static `.a` files in `OTHER_LDFLAGS`
for both Debug and Release in project.pbxproj:

| Library | From | To |
|---|---|---|
| libssl | `-lssl` (dylib) | `/opt/zerobrew/Cellar/openssl@3/3.6.1/lib/libssl.a` |
| libcrypto | `-lcrypto` (dylib) | `/opt/zerobrew/Cellar/openssl@3/3.6.1/lib/libcrypto.a` |
| libfmt | `-lfmt` (dylib) | `/opt/zerobrew/opt/fmt/lib/libfmt.a` |
| libjsoncpp | `-ljsoncpp` (dylib) | `/opt/zerobrew/opt/jsoncpp/lib/libjsoncpp.a` (built from source) |
| liblz4 | `-llz4` (dylib) | `/opt/zerobrew/opt/lz4/lib/liblz4.a` |
| libxxhash | `-lxxhash` (dylib) | `/opt/zerobrew/opt/xxhash/lib/libxxhash.a` |

`libjsoncpp.a` was built from source (jsoncpp 1.9.6 via cmake `-DBUILD_SHARED_LIBS=OFF`)
and installed to `/opt/zerobrew/opt/jsoncpp/lib/libjsoncpp.a`.

The extension binary now has zero zerobrew dynamic dependencies. `otool -L` on the
built extension shows only system frameworks. Build succeeds.

### 9. Tunnel startup timeout increase
Increased the 30-second polling timeout in `OpenVPNPacketTunnelBridge.mm` to 120s
to give the OpenVPN negotiation more time and allow log collection.

### 10. Current status
- Extension no longer crashes on launch.
- VPN shows "Connecting" then fails with "Timed out waiting for tunnel startup."
  This means the extension starts but OpenVPN does not complete the tunnel setup
  within 120s. Root cause unknown — needs Console.app log analysis.
- Error 3 (`missingProfileConfig`) is seen when connecting to a profile whose
  `.ovpn` file path is no longer valid. Root cause: VPN provider payload stores
  a file path, not the config content.

### 11. Connection status and tunnel startup follow-up
- `MenuBarController` now sets the profile state to `connecting` immediately
  before invoking the tunnel start request, so the menu reflects the in-flight
  connection state right away.
- `PacketTunnelProvider` now moves startup work onto a background queue before
  calling into the OpenVPN bridge. That keeps the provider callback path from
  being blocked while tunnel settings are applied.
- Verified with `xcodebuild -project maco.xcodeproj -scheme maco -configuration Debug build`.

### 12. Icon / VPN settings cleanup
- Added `CFBundleIconFile` to the packet tunnel extension plist and copied the
  app icon into the extension bundle so System Settings can display the actual
  app icon for the VPN entry.
- Cleared stale local diagnostic reports for `maco` and `macopackettunnel`
  before the final reconnect test.
- Fresh reconnect completed without the previous `NEVPNConnectionErrorDomain 12`
  failure.

## Planned next (not yet done)
See `2026-04-07-architecture-handoff.md`.
