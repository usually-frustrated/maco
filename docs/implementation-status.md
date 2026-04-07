# Current Implementation Status

## Purpose

This log records what has been implemented so far and where the current stop point is.

## Related Docs

- [Locked Architecture](./architecture-locked.md)
- [Product Goals](./product-goals.md)
- [Implementation Phases](./implementation-phases.md)
- [Implementation Logs](./implementation-logs.md)
- [Implementation Handoff](./implementation-handoff.md)

## Completed Work

### Phase 0: Project Skeleton

Implemented:

- Xcode project with a macOS app target and packet tunnel extension target
- Menu bar app entry point and minimal menu bar controller
- Packet tunnel provider stub
- App and extension entitlements and plist wiring

Key files:

- `maco.xcodeproj/project.pbxproj`
- `maco/App/AppDelegate.swift`
- `maco/App/MenuBarController.swift`
- `macopackettunnel/PacketTunnelProvider.swift`
- `maco/Resources/maco.entitlements`
- `macopackettunnel/Resources/Info.plist`
- `macopackettunnel/Resources/macopackettunnel.entitlements`

### Phase 1: Profile Storage And Import

Implemented:

- Profile import into the shared app-group container at `<app-group>/maco/profiles/<UUID>/`
- Stored `config.ovpn` plus `profile.json` metadata per profile
- Profile listing, removal, and open-folder support
- Import analysis with warnings for unsupported directives
- Tolerant text decoding beyond UTF-8 only

Key files:

- `maco/Profiles/ProfilePaths.swift`
- `maco/Profiles/ProfileRecord.swift`
- `maco/Profiles/ProfileImporter.swift`
- `maco/Profiles/ProfileStore.swift`

### Phase 2: Menu Bar MVP

Implemented:

- Menu bar profile list and empty state
- Import, remove, and open-folder actions from the menu bar
- Minimal status model for menu bar title, symbol, and tooltip
- Lightweight user notifications for passive import/remove/error feedback

Key files:

- `maco/App/MenuBarController.swift`
- `maco/App/MenuBarStatus.swift`
- `maco/App/AppNotificationCenter.swift`

### Phase 3: Credentials And Keychain

Implemented:

- Shared username/password credential API for app and extension targets
- Keychain-backed credential persistence keyed by profile UUID
- Shared Keychain access-group handling for app and extension
- Optional import-time username/password prompt
- Per-profile menu actions to set, replace, and clear saved credentials
- Explicit non-persistence of TOTP

Key files:

- `maco/Credentials/ProfileCredentials.swift`
- `maco/Credentials/KeychainProfileCredentialStore.swift`
- `maco/App/ProfileCredentialsPrompt.swift`
- `maco/App/MenuBarController.swift`
- `maco/Resources/maco.entitlements`
- `macopackettunnel/Resources/macopackettunnel.entitlements`

### Phase 4: System VPN Configuration Layer

Implemented:

- App-side `NETunnelProviderManager` reconciliation for imported profiles
- One saved provider manager per imported profile, identified by an explicit app-owned payload
- Persisted provider payload carrying profile UUID plus resolved profile directory and config paths
- Automatic manager reconciliation on app launch and after profile import or removal

Key files:

- `maco/VPN/SystemVPNConfigurationStore.swift`
- `maco/VPN/VPNProviderPayload.swift`
- `maco/App/MenuBarController.swift`
- `maco.xcodeproj/project.pbxproj`

### Phase 5: Menu Bar Connection Controls And State

Implemented:

- Per-profile connect and disconnect actions in the menu bar
- Per-profile connection state display using `NEVPNStatus`
- App-side observation of `NEVPNStatusDidChange` for managed profiles
- Passive connection-state and failure notifications from menu bar flows

Key files:

- `maco/VPN/VPNConnectionState.swift`
- `maco/VPN/SystemVPNConnectionStore.swift`
- `maco/App/MenuBarController.swift`
- `maco/App/MenuBarStatus.swift`
- `maco/App/AppNotificationCenter.swift`
- `maco.xcodeproj/project.pbxproj`

### Phase 6: Packet Tunnel Startup Contract

Implemented:

- Packet tunnel parsing of the saved provider payload from `NETunnelProviderProtocol`
- Structured startup validation for profile directory, config file, and config readability
- Extension-side loading of shared saved credentials when the resolved config requires `auth-user-pass`
- Distinct setup-time errors before the final deliberate `OpenVPN 3 Core` not-implemented failure

Key files:

- `macopackettunnel/PacketTunnelProvider.swift`
- `macopackettunnel/PacketTunnelStartupContext.swift`
- `macopackettunnel/PacketTunnelStartupError.swift`
- `maco.xcodeproj/project.pbxproj`

## Current Stop Point

- The repo is in the post-refactor Phase 7 state: embedded provider config, menu-state updates, tunnel startup flow, and icon wiring are all in place.
- The project has been renamed to `maco`, and the packet tunnel source tree now lives under `macopackettunnel/`.
- The current build passes with `xcodebuild -project maco.xcodeproj -scheme maco -configuration Debug build`.
- The connection flow now shows `Connecting` immediately in the menu, and the tunnel startup path no longer hits the earlier settings timeout in the latest repro.
- VPN Settings now shows the app icon from the extension bundle as well as the app bundle.

## Not Implemented Yet

- Connect-time credential prompting
- TOTP challenge flow
- Multi-profile concurrent connection validation
- Certificate-auth happy path
- Release hardening and packaging

## Verification Performed So Far

- Repeated `swiftc -typecheck` checks across app, profile, credential, and extension sources
- `plutil -lint` checks for the Xcode project, plist files, and entitlements
- Local `xcodebuild` verification for `maco` and `macopackettunnel` with signing disabled
- Local `xcodebuild` verification after Phase 4 with `-derivedDataPath /tmp/macovpn-derived CODE_SIGNING_ALLOWED=NO`
- Local `xcodebuild` verification after Phase 5 with `-derivedDataPath /tmp/macovpn-derived CODE_SIGNING_ALLOWED=NO`
- Local `xcodebuild` verification after Phase 6 with `-derivedDataPath /tmp/macovpn-derived CODE_SIGNING_ALLOWED=NO`
- Verified the upstream `OpenVPN 3 Core` macOS build path in `/tmp/openvpn3` using `cmake` plus `zerobrew`-provided dependencies, including a successful `ovpncli` build
- Local `xcodebuild` verification after Phase 7 bridge wiring with `-derivedDataPath /tmp/macovpn-derived CODE_SIGNING_ALLOWED=NO`
- Local `xcodebuild` verification after the `maco` rename with `-derivedDataPath /tmp/maco-derived CODE_SIGNING_ALLOWED=NO`
- Local `xcodebuild` verification after the embedded-config and connection-status follow-up with default signing enabled
- Fresh connection repro after clearing stale diagnostic logs completed without the previous `NEVPNConnectionErrorDomain 12` failure
- Review passes that resulted in fixes for:
  - non-default profile-store root handling
  - tolerant profile decoding
  - shared Keychain access-group use
  - password whitespace preservation
  - credential cleanup on profile removal
  - provider payload storage using plain property-list values instead of opaque encoded bytes
  - the correct Swift `NEVPNConnection.startVPNTunnel()` call and explicit failed-state handling in the menu
  - packet tunnel credential requirements limited to configs that actually declare `auth-user-pass`
  - immediate `Connecting` UI state on connect start
  - backgrounded packet-tunnel startup to avoid tunnel-settings timeout
  - extension bundle icon metadata and resource copy for VPN Settings

## Notes For The Next Session

- The implementation logs are the intended handoff entry point for status.
- The architecture, product, and phase docs remain the source of truth for intended behavior and sequencing.
- Use [Implementation Handoff](./implementation-handoff.md) as the starting brief for the next implementation session.
- The app now installs and reconciles system VPN configurations per imported profile.
- The menu bar now exposes connection actions and observed VPN state for managed profiles.
- The packet tunnel now resolves provider payload, config content, and shared credentials, then hands off to a compiling Objective-C++ OpenVPN bridge.
- The current remaining work is product hardening, not basic connect flow or bundle wiring.
