# Implementation Phases

## Purpose

This document defines a phased implementation path where each phase ends in a slightly usable MVP. It is written to support future execution in separate threads without requiring a large project-management layer.

Implemented work is tracked in [Implementation Logs](./implementation-logs.md).

## Execution Rules

- Each phase should end in a working, testable slice.
- Prefer vertical slices over broad scaffolding.
- Do not create speculative abstractions.
- Keep docs minimal and update only when a decision or workflow actually changes.
- If a phase reveals a blocked assumption, verify it immediately and fold the result back into the architecture docs.

## Phase 0: Project Skeleton

### Goal

Create the minimum repo and Xcode project structure for a macOS menu bar app plus packet tunnel extension.

### Scope

- Create the app target
- Create the packet tunnel provider target
- Establish bundle structure, entitlements, and basic build settings
- Add `OpenVPN 3 Core` integration strategy placeholder
- Add a tiny docs footprint and local dev instructions only if needed

### MVP Outcome

- The project builds locally
- The app launches as a menu bar extra
- The packet tunnel extension target exists and is wired into the project

## Phase 1: Profile Storage And Import

### Goal

Support importing and persisting `.ovpn` profiles in a user-visible config directory.

### Scope

- Define the on-disk layout under `~/.config/...`
- Import `.ovpn` files into app-managed profile directories
- Store profile metadata needed for listing and connection
- Add remove profile support
- Add "open profiles folder" support
- Tolerate unsupported directives with warnings where possible

### MVP Outcome

- A user can import a real `.ovpn` file
- Imported profiles appear in the menu bar
- A user can remove a profile
- A user can open the local profile storage folder
- No connection yet

## Phase 2: Menu Bar MVP

### Goal

Make the menu bar the single usable app surface for profile operations.

### Scope

- Show profile list
- Show idle/imported/basic status state
- Support import/remove/open-folder actions
- Define a minimal status model and notification helper

### MVP Outcome

- A user can manage profiles entirely from the menu bar
- The app feels like a small native utility rather than a half-built desktop app

## Phase 3: Credentials And Keychain

### Goal

Add credential capture and persistence with Keychain.

### Scope

- Prompt optionally for username/password during import
- Prompt on first connect when credentials are missing
- Save username/password to Keychain
- Never persist TOTP
- Define one simple credential API shared by app and extension

### MVP Outcome

- Profiles can have credentials attached
- Missing credentials are collected at connect time and persisted correctly
- Keychain-backed auth data is working before VPN connection logic arrives

## Phase 4: System VPN Configuration Layer

### Goal

Create the app-side `NetworkExtension` configuration model that maps imported profiles to system VPN configurations.

### Scope

- Add an app-side wrapper around `NETunnelProviderManager`
- Create one provider configuration per imported profile
- Persist and reload provider configurations on app launch
- Define the provider payload that identifies the profile UUID and on-disk config
- Reconcile imported profiles with saved `NetworkExtension` managers cleanly

### MVP Outcome

- One imported profile can be installed as a system VPN configuration
- The app has a stable per-profile identity model for later connect/disconnect work

## Phase 5: Menu Bar Connection Controls And State

### Goal

Expose connect/disconnect operations and current per-profile state through the menu bar.

### Scope

- Add per-profile connect and disconnect actions
- Observe `NetworkExtension` status changes
- Show connecting, connected, disconnecting, and failed states in the menu bar
- Send notifications for passive connection state and failure updates
- Keep the menu bar as the only app-owned control surface

### MVP Outcome

- A user can start and stop one configured profile from the menu bar
- App state reflects system VPN lifecycle instead of import-only state

## Phase 6: Packet Tunnel Startup Contract

### Goal

Define and implement the startup contract between the app and the packet tunnel extension.

### Scope

- Parse provider configuration inside `NEPacketTunnelProvider`
- Resolve the imported profile directory and config file from the provider payload
- Load shared username/password credentials inside the extension
- Return structured startup errors instead of the current stub failure
- Keep extension startup logic small and easy to reason about before adding the VPN engine

### MVP Outcome

- Tunnel startup reaches real profile-loading code in the extension
- Failures now identify missing profile/config/credential setup precisely

## Phase 7: OpenVPN Core Single-Profile Connection

### Goal

Get one imported profile connecting through `OpenVPN 3 Core`.

### Scope

- Add the OpenVPN core dependency
- Define the Swift-side wrapper around the engine
- Load the imported `.ovpn` into the engine
- Translate engine lifecycle into tunnel lifecycle callbacks
- Implement real connect/disconnect plumbing for one profile

### MVP Outcome

- One imported profile can attempt a real connection from the menu bar
- Basic connection lifecycle is visible in app state

## Phase 8: Connect-Time Credentials And TOTP

### Goal

Support the first-release auth flow for username/password plus TOTP.

### Scope

- Prompt for username/password on connect when credentials are missing
- Save newly entered username/password to Keychain after successful entry
- Detect the TOTP-relevant challenge flow needed by the current setup
- Prompt for OTP at connection time
- Pass OTP into the OpenVPN auth flow
- Never persist TOTP
- Handle retry and failure states cleanly

### MVP Outcome

- A real profile using username/password + TOTP can connect end-to-end
- Missing saved credentials no longer block first use
- OTP is always entered fresh

## Phase 9: Multi-Profile Operation And Validation

### Goal

Support multiple saved profiles and verify the concurrent-connection model early enough to correct course if needed.

### Scope

- Finalize per-profile configuration identity across app, extension, and Keychain
- Support multiple provider configurations cleanly
- Track state per profile
- Validate whether multiple profiles can be active at once in the chosen architecture
- If concurrency does not work cleanly, document the exact platform constraint and adjust the design intentionally

### MVP Outcome

- The app can manage many profiles cleanly
- The project has a verified answer on concurrent active profiles
- If concurrency works, multiple profiles can connect independently

## Phase 10: Certificate Happy Path And Import Validation

### Goal

Add minimal certificate-based support if it fits cleanly, and tighten import behavior around unusable configurations.

### Scope

- Support the simplest viable cert/key import path
- Use native Keychain-backed handling where practical
- Reject unsupported cert setups clearly rather than partially faking support
- Distinguish between:
  - imported and usable
  - imported with warnings
  - rejected because connection cannot be made correctly or safely
- Surface import warnings and rejection reasons clearly enough for handoff and debugging

### MVP Outcome

- Some common certificate-based `.ovpn` profiles work
- Unsupported certificate variants fail clearly and intentionally

## Phase 11: Hardening And Test Coverage

### Goal

Reduce risk in the connection and import path before packaging.

### Scope

- Import and connection error cleanup
- Basic test coverage for the critical core pieces
- Regression coverage for profile-manager mapping, provider payloads, and auth handling
- User-facing warnings for partially supported configs

### MVP Outcome

- The app is usable by real users with known implementation constraints
- The highest-risk flows have repeatable verification

## Phase 12: Release Prep

### Goal

Make the app shippable through GitHub Releases.

### Scope

- Signing and notarization workflow
- Release checklist
- Install/build documentation only where it is actually needed
- Final packaging verification

### MVP Outcome

- A GitHub Releases build can be produced and installed
- Release steps are explicit enough to hand off cleanly

## Suggested Working Order Inside Each Phase

1. Confirm assumptions for that phase.
2. Implement the smallest vertical slice.
3. Verify locally.
4. Update only the docs that actually changed.
5. Leave the repo in a handoff-ready state for the next thread.
