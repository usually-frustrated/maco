# Implementation Phases

## Purpose

This document defines a phased implementation path where each phase ends in a slightly usable MVP. It is written to support future execution in separate threads without requiring a large project-management layer.

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

## Phase 4: OpenVPN Core Integration

### Goal

Get the packet tunnel extension talking to `OpenVPN 3 Core`.

### Scope

- Add the OpenVPN core dependency
- Define the Swift-side wrapper around the engine
- Load imported profile config into the engine
- Establish the tunnel-provider control flow
- Implement connect/disconnect plumbing for one profile

### MVP Outcome

- One imported profile can attempt a real connection from the menu bar
- Basic connection lifecycle is visible in app state

## Phase 5: TOTP Connection Flow

### Goal

Support username/password plus TOTP during connection.

### Scope

- Detect the TOTP-relevant challenge flow needed by the current setup
- Prompt for OTP at connection time
- Pass OTP into the OpenVPN auth flow
- Handle retry and failure states cleanly
- Use notifications for passive status and errors

### MVP Outcome

- A real profile using username/password + TOTP can connect end-to-end
- OTP is always entered fresh

## Phase 6: Multi-Profile Operation

### Goal

Support multiple saved profiles and validate the concurrent-connection model.

### Scope

- Finalize per-profile configuration identity
- Support multiple provider configurations
- Track state per profile
- Validate whether multiple profiles can be active at once in the chosen architecture
- If needed, adjust the persistence and session model without breaking earlier phases

### MVP Outcome

- The app can manage many profiles cleanly
- The project has a verified answer on concurrent active profiles
- If concurrency works, multiple profiles can connect independently

## Phase 7: Certificate Happy Path

### Goal

Add minimal certificate-based support if it fits the architecture cleanly.

### Scope

- Support the simplest viable cert/key import path
- Use native Keychain-backed handling where practical
- Reject unsupported cert setups clearly rather than partially faking support

### MVP Outcome

- Some common certificate-based `.ovpn` profiles work
- Unsupported certificate variants fail clearly and intentionally

## Phase 8: Hardening And Release Prep

### Goal

Make the app shippable through GitHub Releases.

### Scope

- Signing and notarization workflow
- Import and connection error cleanup
- User-facing warnings for partially supported configs
- Basic test coverage for the critical core pieces
- Release checklist

### MVP Outcome

- A GitHub Releases build can be produced and installed
- The app is usable by real users with known constraints

## Suggested Working Order Inside Each Phase

1. Confirm assumptions for that phase.
2. Implement the smallest vertical slice.
3. Verify locally.
4. Update only the docs that actually changed.
5. Leave the repo in a handoff-ready state for the next thread.
