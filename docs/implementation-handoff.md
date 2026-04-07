# Implementation Handoff

## Purpose

This document is the starting point for the next implementation session after the current Phase 6 slice.

Use this with:

- [Locked Architecture](./architecture-locked.md)
- [Implementation Phases](./implementation-phases.md)
- [Current Implementation Status](./implementation-status.md)

## Verified Current State

- The repo builds locally in Xcode for both `maco` and `macopackettunnel` with signing disabled.
- The renamed project also builds locally with `xcodebuild -project maco.xcodeproj -scheme maco -configuration Debug -sdk macosx -derivedDataPath /tmp/maco-derived CODE_SIGNING_ALLOWED=NO build`.
- The upstream `OpenVPN 3 Core` macOS dependency path is also verified locally with `cmake` plus `zerobrew`-provided libraries.
- The app currently implements:
  - menu bar launch and profile listing
  - `.ovpn` import into the shared app-group container at `<app-group>/maco/profiles/<UUID>/`
  - profile removal and open-folder support
  - import-time unsupported-directive warnings
  - Keychain-backed username/password save, replace, clear, and load
  - app-side reconciliation of one saved `NETunnelProviderManager` per imported profile
  - provider payload persistence carrying profile UUID plus profile directory and config paths
  - menu bar connect/disconnect actions for managed profiles
  - observed per-profile VPN state from `NEVPNStatusDidChange`
  - passive VPN notifications for connecting, connected, disconnecting, disconnected, and failed states
- The packet tunnel now resolves provider payload, config paths, and shared credentials, then hands off to a compiling Objective-C++ OpenVPN bridge.
- The shared app-group container path is wired for profile storage and the packet tunnel startup path reads from that path in code, but signed runtime validation has not been proven in this environment yet.

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
- Phase 7 still needs a real signed-runtime validation that the packet tunnel can read imported profile files from the shared app-group container under the sandbox model.
- The dependency toolchain is already validated locally, so the next session should use it instead of spending time on setup discovery.

## Files Most Likely To Change First

- a small Objective-C++ bridge or wrapper for `OpenVPN 3 Core`
- one or two packet-tunnel-only files for the client lifecycle and tunnel builder surface
- `macopackettunnel/PacketTunnelProvider.swift`
- `macopackettunnel/PacketTunnelStartupContext.swift`

## Guardrails

- Keep the menu bar as the only app-owned control surface.
- Keep files small and split by responsibility.
- Avoid speculative wrappers around `NetworkExtension` or OpenVPN.
- Preserve the current Keychain shape unless a platform constraint forces a documented change.
- Validate the multi-profile model early enough to avoid rework.
- Phase 7 should explicitly verify whether the packet tunnel can read the shared app-group profile paths under the signed sandbox model before broadening the bridge surface.
- Use the verified local dependency path:
  - `PATH=/opt/zerobrew/bin:$PATH`
  - `PKG_CONFIG_PATH=/opt/zerobrew/opt/openssl@3/lib/pkgconfig:/opt/zerobrew/opt/fmt/lib/pkgconfig:/opt/zerobrew/opt/jsoncpp/lib/pkgconfig:/opt/zerobrew/opt/lz4/lib/pkgconfig:/opt/zerobrew/opt/xxhash/lib/pkgconfig`
  - `OPENSSL_ROOT_DIR=/opt/zerobrew/opt/openssl@3`
  - `CMAKE_PREFIX_PATH=/opt/zerobrew/opt`
- Keep Phase 7 to one profile and one engine path until the basic connection lifecycle is proven.

## Current Blocker

- Signed packet-tunnel runtime validation of the shared app-group profile read path is still unresolved in this environment.
- The next implementation step is to prove the packet tunnel can launch under a signed sandboxed build and read `config.ovpn` from `<app-group>/maco/profiles/<UUID>/config.ovpn` before expanding the OpenVPN bridge further.

## Beta Release Prep

- Xcode Release signing should stay on automatic management with the shared team selected; do not hard-code an Apple Distribution identity in build settings.
- The app and packet tunnel targets both need the Network Extension, App Sandbox, App Groups, and Keychain Sharing capabilities aligned with their entitlements.
- Use Xcode `Product > Archive`, then `Distribute App > App Store Connect > Upload` from Organizer for the beta build.
- If provisioning fails, refresh signing assets in Xcode `Settings > Accounts` and confirm Apple has approved the Network Extension entitlement for both bundle IDs.
- Increment the build number before each upload so TestFlight receives a unique archive.
- The app icon now comes from the `Assets.xcassets` `AppIcon` asset, so the legacy `.icns` file is no longer part of the active bundle wiring.
- The menu bar status item now renders the Unicode glyph `⦼` with a little padding instead of an image.

## Handoff To Next Thread

- Start from `maco.xcodeproj` and the `maco` scheme.
- Keep Phase 7 scoped to one imported profile and one OpenVPN 3 Core connection path.
- First prove the packet tunnel can launch signed and read the shared profile file path.
- If that succeeds, finish the smallest possible real tunnel connection path and stop.
