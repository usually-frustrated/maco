# 2026-04-09: App Store Network Extension Permission Fix

## Goal

Fix the App Store import/connect failure path where saved VPN profiles were denied by the system or were not immediately visible after saving.

## What Changed

- Added the `com.apple.developer.networking.networkextension` entitlement to both the app and packet tunnel targets using `packet-tunnel-provider-systemextension`, which matches the current Xcode target type.
- Added `com.apple.developer.networking.vpn.api` to the app target so the container app is explicitly entitled to create and control VPN configurations.
- Added a post-save preferences reload check in `SystemVPNConfigurationStore` so imported profiles are only reported as saved once macOS can read them back.

## Why

- The App Store build was surfacing `NEVPNErrorDomain 5` permission-denied failures during profile import.
- The project currently embeds the tunnel as a system extension product, so the `networkextension` entitlement has to match that product type.
- The app target is the process that calls `NETunnelProviderManager.saveToPreferences`, so it also needs the VPN-control entitlement.
- The connect path could then fail with `No VPN configuration exists for this profile` if the saved manager had not yet appeared in preferences.

## Verification

- `plutil -lint` passes for both entitlement files after the entitlement shape change.

## Follow-Up

- Rebuild the App Store configuration and re-test `.ovpn` import plus first connect.
