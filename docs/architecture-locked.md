# Locked Architecture

## Purpose

This document records the architecture decisions that are already locked for the first version of the project, plus a small number of explicitly deferred items. It is the canonical reference for what the system is and is not trying to be.

Implemented work is tracked in [Implementation Logs](./implementation-logs.md).

## Product Shape

- Native macOS OpenVPN client
- Built with Swift
- Uses Apple-native VPN integration points wherever possible
- Uses `OpenVPN 3 Core` instead of reimplementing OpenVPN behavior
- Uses a minimal menu bar surface for the app-owned workflows that macOS does not natively provide
- Uses notifications for passive information

## Locked Decisions

### Platform Integration

- Use Apple's `NetworkExtension` framework.
- Use a packet tunnel provider via `NEPacketTunnelProvider`.
- Manage VPN configurations through the system-managed macOS VPN model as much as possible.
- Prefer native macOS surfaces over custom app UI whenever the workflow is actually supported there.

### Language and Core Stack

- Use Swift for the application and extension.
- Use `OpenVPN 3 Core` as the VPN engine.
- Do not involve Rust in v1.
- Do not build a new VPN library or protocol implementation.

### Distribution

- Initial distribution is through GitHub Releases.
- App Store support is a later concern and should not distort v1 decisions unnecessarily.

### User Experience Model

- The app-owned control surface is a minimal menu bar extra.
- The menu bar is the single app-owned UI path.
- Passive information should be shown with notifications and concise menu bar state.
- Avoid redundant controls or elaborate settings screens.
- Do not build a separate rich settings app.

### Menu Bar Scope

The menu bar surface should support only:

- Import profile
- Remove profile
- Connect profile
- Disconnect profile
- View current connection state
- Open the local profile storage folder
- Enter credentials or OTP only when required

Out of scope for v1:

- Rich profile editing
- Extensive diagnostics UI
- Duplicate connection controls in multiple places

### Profile Model

- Support importing generic `.ovpn` files in v1.
- Support many saved profiles.
- Multiple profiles should be allowed at once as a product requirement.
- Imported profiles should be stored locally in a user-visible, user-editable app directory.
- Use a user-scoped config directory rather than embedding imported source files in random locations.

Locked storage direction:

- Use a shared app-group container for imported profiles and related user-maintained files so the packet tunnel extension can read them under sandbox.
- Active layout: `<app-group>/maco/profiles/<UUID>/config.ovpn` and `<app-group>/maco/profiles/<UUID>/profile.json`
- Preserve legacy `~/.config/maco/profiles/...` data long enough to migrate it into the shared container.
- Files we maintain for the user should be easy to inspect, open, and edit directly.
- The app should treat on-disk profile files as user-visible configuration, not hidden internal implementation state.

### Credentials and Secrets

- Always use macOS Keychain for persisted secrets.
- Username and password may be set up at import time, but that must be optional.
- If credentials are not already saved, the first connection attempt should prompt for them.
- After successful entry, credentials should be saved to Keychain.
- TOTP codes must always be entered fresh and must not be persisted.
- The current Keychain shape is one generic password item per profile UUID, storing a JSON username/password payload only, using the shared `keychain-access-groups` entitlement for the app and packet tunnel extension.

### Authentication Support

Locked for v1:

- Username/password authentication
- TOTP-based OTP entry during connection

Design requirement for later:

- Leave room for broader MFA challenge handling in future versions
- Avoid designing the auth flow as permanently TOTP-only

Certificate support:

- Not a primary v1 requirement
- If a minimal happy-path implementation is straightforward and fits the architecture cleanly, it is acceptable to include
- The architecture must not block future certificate-based auth

### Import Behavior

- Import should be tolerant by default.
- Unsupported directives should not hard-fail unless they make the profile unusable or unsafe.
- Prefer importing with clear warnings when possible.

This means v1 should distinguish between:

- Supported and usable
- Imported with warnings or degraded behavior
- Rejected because connection cannot be made correctly or safely

## Explicit Non-Goals

- Reimplementing OpenVPN behavior
- Writing a new VPN framework or networking stack
- Building a large custom settings experience outside native macOS surfaces
- Building multiple overlapping user interaction paths for the same action

## Important Early Verification Item

This is not a product choice to be made later. The product requirement is already locked:

- Multiple profiles should be allowed at once

The engineering question is narrower:

- Can we support multiple concurrently active imported OpenVPN profiles cleanly using `NetworkExtension` and one independent tunnel/provider configuration per profile, with sane lifecycle behavior, state reporting, credential access, and profile isolation?

This must be validated early because it affects:

- Configuration modeling
- Persistence format
- Naming and identity of provider configurations
- Menu bar interaction model
- Concurrent status tracking
- Keychain item scoping
- Extension-to-app communication

The requirement is not "decide whether multiple active profiles are desirable."
The requirement is "confirm the exact Apple/OpenVPN integration model that makes this possible."

## Open Items That Are Not Locked Yet

- Exact UI behavior for OTP prompt timing and retry
- Exact extent of minimal certificate-auth happy-path support in v1
- Exact warning model for partially supported `.ovpn` directives
