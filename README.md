# maco

`maco` is a small macOS OpenVPN client that lives in the menu bar.

## What It Does

- Import `.ovpn` profiles
- Save multiple profiles locally
- Connect and disconnect from the menu bar
- Store usernames and passwords in Keychain
- Keep profile files in a user-visible folder

## How To Use It

1. Open `maco`.
2. Import a `.ovpn` profile.
3. Enter saved credentials if prompted.
4. Connect from the menu bar.

## Profile Files

Imported profiles are stored in a shared app-group container so the app and packet tunnel can read them at runtime.

The profile files remain user-editable on disk.

## Current State

`maco` is under active development.

The menu bar workflow, profile import, credentials, and VPN configuration plumbing are in place.
OpenVPN 3 Core connection runtime validation is still being finished.

## Notes

- TOTP is not persisted.
- Certificate-based support is minimal for now.
- The app is intentionally small and focused on the core VPN workflow.
