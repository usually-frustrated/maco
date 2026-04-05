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

- `MacOVPN.xcodeproj/project.pbxproj`
- `MacOVPN/App/AppDelegate.swift`
- `MacOVPN/App/MenuBarController.swift`
- `MacOVPNPacketTunnel/PacketTunnelProvider.swift`
- `MacOVPN/Resources/MacOVPN.entitlements`
- `MacOVPNPacketTunnel/Resources/Info.plist`
- `MacOVPNPacketTunnel/Resources/MacOVPNPacketTunnel.entitlements`

### Phase 1: Profile Storage And Import

Implemented:

- Profile import into `~/.config/MacOVPN/profiles/<UUID>/`
- Stored `config.ovpn` plus `profile.json` metadata per profile
- Profile listing, removal, and open-folder support
- Import analysis with warnings for unsupported directives
- Tolerant text decoding beyond UTF-8 only

Key files:

- `MacOVPN/Profiles/ProfilePaths.swift`
- `MacOVPN/Profiles/ProfileRecord.swift`
- `MacOVPN/Profiles/ProfileImporter.swift`
- `MacOVPN/Profiles/ProfileStore.swift`

### Phase 2: Menu Bar MVP

Implemented:

- Menu bar profile list and empty state
- Import, remove, and open-folder actions from the menu bar
- Minimal status model for menu bar title, symbol, and tooltip
- Lightweight user notifications for passive import/remove/error feedback

Key files:

- `MacOVPN/App/MenuBarController.swift`
- `MacOVPN/App/MenuBarStatus.swift`
- `MacOVPN/App/AppNotificationCenter.swift`

### Phase 3: Credentials And Keychain

Implemented:

- Shared username/password credential API for app and extension targets
- Keychain-backed credential persistence keyed by profile UUID
- Shared Keychain access-group handling for app and extension
- Optional import-time username/password prompt
- Per-profile menu actions to set, replace, and clear saved credentials
- Explicit non-persistence of TOTP

Key files:

- `MacOVPN/Credentials/ProfileCredentials.swift`
- `MacOVPN/Credentials/KeychainProfileCredentialStore.swift`
- `MacOVPN/App/ProfileCredentialsPrompt.swift`
- `MacOVPN/App/MenuBarController.swift`
- `MacOVPN/Resources/MacOVPN.entitlements`
- `MacOVPNPacketTunnel/Resources/MacOVPNPacketTunnel.entitlements`

## Current Stop Point

- The repo is currently at the end of Phase 3.
- The next incomplete phase is Phase 4: System VPN Configuration Layer.

## Not Implemented Yet

- OpenVPN 3 Core dependency integration
- Tunnel connect and disconnect flow
- Connect-time credential prompting
- TOTP challenge flow
- Multi-profile concurrent connection validation
- Certificate-auth happy path
- Release hardening and packaging

## Verification Performed So Far

- Repeated `swiftc -typecheck` checks across app, profile, credential, and extension sources
- `plutil -lint` checks for the Xcode project, plist files, and entitlements
- Local `xcodebuild` verification for `MacOVPN` and `MacOVPNPacketTunnel` with signing disabled
- Review passes that resulted in fixes for:
  - non-default profile-store root handling
  - tolerant profile decoding
  - shared Keychain access-group use
  - password whitespace preservation
  - credential cleanup on profile removal

## Notes For The Next Session

- The implementation logs are the intended handoff entry point for status.
- The architecture, product, and phase docs remain the source of truth for intended behavior and sequencing.
- Use [Implementation Handoff](./implementation-handoff.md) as the starting brief for the first post-Phase-3 implementation session.
- OpenVPN 3 Core integration and real tunnel lifecycle work are still required before the post-Phase-3 connection phases can be considered complete.
