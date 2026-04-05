# Implementation Handoff

## Purpose

This document is the starting point for the next implementation session after the current Phase 0-3 slice.

Use this with:

- [Locked Architecture](./architecture-locked.md)
- [Implementation Phases](./implementation-phases.md)
- [Current Implementation Status](./implementation-status.md)

## Verified Current State

- The repo builds locally in Xcode for both `MacOVPN` and `MacOVPNPacketTunnel` with signing disabled.
- The app currently implements:
  - menu bar launch and profile listing
  - `.ovpn` import into `~/.config/MacOVPN/profiles/<UUID>/`
  - profile removal and open-folder support
  - import-time unsupported-directive warnings
  - Keychain-backed username/password save, replace, clear, and load
- The packet tunnel provider is still a stub and does not connect.

## What The Code Does Not Do Yet

- No `NETunnelProviderManager` integration
- No connect or disconnect actions
- No current connection state
- No provider startup contract beyond a stub failure
- No `OpenVPN 3 Core` integration
- No connect-time credential prompt
- No TOTP challenge flow
- No multi-profile concurrency validation
- No certificate-auth happy path

## Recommended Next Working Order

1. Add the app-side VPN manager layer around `NETunnelProviderManager`.
2. Add menu bar connect/disconnect actions and per-profile state observation.
3. Define the provider configuration payload and extension startup contract.
4. Integrate `OpenVPN 3 Core` and get one profile connecting.
5. Add connect-time missing-credential prompting.
6. Add TOTP challenge handling.
7. Validate whether multiple profiles can be active concurrently.
8. Add minimal certificate support or explicit rejection.
9. Harden import validation and add tests.
10. Finish signing, notarization, and release prep.

## Immediate Next Slice

The next agent should start with Phase 4, not with OpenVPN integration directly.

Reason:

- The app currently has no system VPN configuration model.
- Without that layer, later connect/disconnect, state reporting, and multi-profile identity will be bolted on instead of designed cleanly.
- The architecture already requires one clean identity per imported profile across menu state, system VPN config, extension startup, and Keychain.

## Files Most Likely To Change First

- `MacOVPN/App/MenuBarController.swift`
- `MacOVPN/App/MenuBarStatus.swift`
- new small files under `MacOVPN/App/` or a new `MacOVPN/VPN/` area for app-side VPN manager logic
- `MacOVPNPacketTunnel/PacketTunnelProvider.swift`

## Guardrails

- Keep the menu bar as the only app-owned control surface.
- Keep files small and split by responsibility.
- Avoid speculative wrappers around `NetworkExtension` or OpenVPN.
- Preserve the current profile storage layout and Keychain shape unless a platform constraint forces a documented change.
- Validate the multi-profile model early enough to avoid rework.
