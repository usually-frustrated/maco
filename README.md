<div align="center">


<img src="docs/maco-icon/web/icon-192.png" width="64" />

# maco

`maco` is a small native macOS OpenVPN client that lives in the menu bar.

</div>


## What It Does

- Import `.ovpn` profiles
- Save multiple profiles in System VPN preferences
- Connect and disconnect from the menu bar
- Store usernames and passwords in Keychain
- Keep the imported profile content in the VPN configuration itself

## How To Use It

1. Open `maco`.
2. Import a `.ovpn` profile.
3. Enter saved credentials if prompted.
4. Connect from the menu bar.

## Storage

Imported `.ovpn` content is embedded in the VPN configuration and managed by macOS.
Saved usernames and passwords live in Keychain.
TOTP is not persisted.

## Current State

`maco` is under active development.
The menu bar workflow, profile import, credentials, VPN state, and tunnel startup are in place.
OpenVPN runtime hardening and broader auth support are still being finished.
