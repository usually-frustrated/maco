# Implementation Handoff

## Purpose

This document is the starting point for the next implementation session after the current Phase 6 slice.

Use this with:

- [Locked Architecture](./architecture-locked.md)
- [Implementation Phases](./implementation-phases.md)
- [Current Implementation Status](./implementation-status.md)

## Verified Current State

- The repo builds locally in Xcode for both `MacOVPN` and `MacOVPNPacketTunnel` with signing disabled.
- The upstream `OpenVPN 3 Core` macOS dependency path is also verified locally with `cmake` plus `zerobrew`-provided libraries.
- The app currently implements:
  - menu bar launch and profile listing
  - `.ovpn` import into `~/.config/MacOVPN/profiles/<UUID>/`
  - profile removal and open-folder support
  - import-time unsupported-directive warnings
  - Keychain-backed username/password save, replace, clear, and load
  - app-side reconciliation of one saved `NETunnelProviderManager` per imported profile
  - provider payload persistence carrying profile UUID plus profile directory and config paths
  - menu bar connect/disconnect actions for managed profiles
  - observed per-profile VPN state from `NEVPNStatusDidChange`
  - passive VPN notifications for connecting, connected, disconnecting, disconnected, and failed states
- The packet tunnel now resolves provider payload, config paths, and shared credentials, then stops at a deliberate “OpenVPN core not implemented yet” error.

## What The Code Does Not Do Yet

- No `OpenVPN 3 Core` integration
- No connect-time credential prompt
- No TOTP challenge flow
- No multi-profile concurrency validation
- No certificate-auth happy path

## Recommended Next Working Order

1. Integrate `OpenVPN 3 Core` and get one profile connecting.
2. Add connect-time missing-credential prompting.
3. Add TOTP challenge handling.
4. Validate whether multiple profiles can be active concurrently.
5. Add minimal certificate support or explicit rejection.
6. Harden import validation and add tests.
7. Finish signing, notarization, and release prep.

## Immediate Next Slice

The next agent should start with Phase 7, while keeping scope to one real profile connection path and the smallest possible OpenVPN bridge surface.

Reason:

- The app and extension now agree on profile identity, provider payload, and startup-time credential resolution.
- The next missing layer is the actual OpenVPN engine and tunnel lifecycle integration for one profile.
- Phase 7 should stop immediately if the extension cannot read the persisted `~/.config/MacOVPN/...` files under the signed sandbox model, because that is now the clearest concrete platform risk.
- The dependency toolchain is already validated locally, so the next session should use it instead of spending time on setup discovery.

## Files Most Likely To Change First

- a small Objective-C++ bridge or wrapper for `OpenVPN 3 Core`
- one or two packet-tunnel-only files for the client lifecycle and tunnel builder surface
- `MacOVPNPacketTunnel/PacketTunnelProvider.swift`
- `MacOVPNPacketTunnel/PacketTunnelStartupContext.swift`

## Guardrails

- Keep the menu bar as the only app-owned control surface.
- Keep files small and split by responsibility.
- Avoid speculative wrappers around `NetworkExtension` or OpenVPN.
- Preserve the current profile storage layout and Keychain shape unless a platform constraint forces a documented change.
- Validate the multi-profile model early enough to avoid rework.
- Phase 7 should explicitly verify whether the packet tunnel can read the current `~/.config/MacOVPN/...` paths under the signed sandbox model, because Phase 4 now persists those paths into the provider payload.
- Use the verified local dependency path:
  - `PATH=/opt/zerobrew/bin:$PATH`
  - `PKG_CONFIG_PATH=/opt/zerobrew/opt/openssl@3/lib/pkgconfig:/opt/zerobrew/opt/fmt/lib/pkgconfig:/opt/zerobrew/opt/jsoncpp/lib/pkgconfig:/opt/zerobrew/opt/lz4/lib/pkgconfig:/opt/zerobrew/opt/xxhash/lib/pkgconfig`
  - `OPENSSL_ROOT_DIR=/opt/zerobrew/opt/openssl@3`
  - `CMAKE_PREFIX_PATH=/opt/zerobrew/opt`
- Keep Phase 7 to one profile and one engine path until the basic connection lifecycle is proven.
