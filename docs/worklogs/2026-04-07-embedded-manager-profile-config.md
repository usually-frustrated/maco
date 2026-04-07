# Worklog - Embedded Manager Profile Config Refactor

## Summary

Reworked profile management so `NETunnelProviderManager` is the only profile store.
Imported `.ovpn` content is embedded directly in `providerConfiguration`, and the
packet tunnel startup path now reads the embedded content instead of files on disk.

## Completed Changes

- Replaced the old payload file-path fields with embedded config content.
- Simplified system VPN configuration management to add/remove managers by profile ID.
- Added manager-backed profile enumeration for the menu bar.
- Removed the file-backed profile store and deleted the retired profile store types.
- Updated packet tunnel startup to use embedded config content and removed file I/O.
- Updated the menu bar flow to import raw `.ovpn` content, prompt for credentials,
  and synchronize against `NETunnelProviderManager` entries.
- Added best-effort cleanup for orphaned Keychain credentials after VPN sync.

## Verification

- Repository-wide reference check completed for deleted profile-store types.
- Full Xcode build passed with `xcodebuild -project maco.xcodeproj -scheme maco -configuration Debug build`.
- Fresh reconnect after the refactor completed without the previous `NEVPNConnectionErrorDomain 12` failure.
