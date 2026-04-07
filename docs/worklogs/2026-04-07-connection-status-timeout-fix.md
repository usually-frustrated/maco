# 2026-04-07: Connection Status And Tunnel Startup Fix

## What changed

- `MenuBarController` now marks a profile as `connecting` immediately before
  calling `startVPNTunnel`, so the menu reflects the in-flight connection state
  instead of waiting for the extension callback.
- `PacketTunnelProvider` now performs startup work on a background queue before
  invoking the OpenVPN bridge, which avoids blocking the tunnel settings
  completion path.

## Why this was needed

The tunnel was reaching `CONNECTING` and then timing out while waiting for
network settings to be applied. The extension log showed:

- `Timed out applying tunnel settings.`

That pointed to the provider callback path being delayed long enough for the
bridge's settings wait loop to expire.

## Verification

- `xcodebuild -project maco.xcodeproj -scheme maco -configuration Debug build`
  succeeded after the change.

## Notes

- The UI now shows `Connecting` as soon as the user starts a connection.
- The tunnel startup timeout path still reports the bridge error text if the
  extension cannot finish applying settings in time.
