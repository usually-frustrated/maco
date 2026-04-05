# Product Goals

## Purpose

This document describes what the project is trying to build at a high level. It is intentionally not a detailed design or implementation plan.

Implemented work is tracked in [Implementation Logs](./implementation-logs.md).

## Development Goals

- Build a native macOS OpenVPN client without reinventing the VPN stack
- Reuse existing proven components wherever possible
- Keep the project intentionally small in scope and surface area
- Prefer Apple-native system integration over custom application behavior
- Make `.ovpn` import a first-class workflow
- Support multiple saved profiles
- Support username/password plus TOTP-based connection flow in the first release
- Persist long-lived secrets in macOS Keychain
- Keep future MFA expansion possible without redesigning the whole app

## Implementation Goals

- Use Swift as the implementation language
- Use Apple's `NetworkExtension` for VPN integration
- Use `OpenVPN 3 Core` for the OpenVPN engine
- Package the app with a packet tunnel provider extension
- Keep the app-owned UI minimal and concentrated in a menu bar extra
- Use notifications for passive status and error reporting
- Store imported profile artifacts in one predictable user-visible location under `~/.config/...`
- Avoid feature creep such as broad profile editing, custom diagnostics suites, or heavyweight settings screens

## Runtime Goals

- Feel native on macOS
- Let the system own as much of the VPN lifecycle as possible
- Require the smallest possible custom UI surface
- Support importing, saving, selecting, and connecting multiple OpenVPN profiles
- Keep maintained profile files directly viewable and editable by the user
- Prompt for username/password if needed and save them to Keychain
- Prompt for TOTP fresh at connection time
- Report state clearly with menu bar state and notifications
- Avoid redundant ways of doing the same thing

## Success Criteria

At a top level, the first version is successful if it can:

- Import a real `.ovpn` profile
- Let the user optionally set credentials during import
- Save credentials to Keychain
- Prompt for missing credentials on first connect
- Prompt for a TOTP code during connection
- Connect and disconnect cleanly through a native-feeling macOS flow
- Manage multiple profiles without a large custom UI

## Non-Goals

- Building a new OpenVPN implementation
- Creating a full custom VPN settings application
- Solving every MFA or certificate-auth edge case in the first release
- Providing multiple redundant control surfaces for the same actions
