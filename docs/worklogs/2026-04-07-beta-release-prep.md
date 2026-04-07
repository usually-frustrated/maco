# 2026-04-07: Beta Release Prep

## Goal

Get the project into a state where a beta build can be archived and uploaded through App Store Connect/TestFlight.

## What Changed

- Moved the Release configuration toward distribution-ready automatic signing.
- Confirmed the app target already carries the sandbox, app group, keychain, and network extension entitlements needed for App Store distribution.
- Confirmed the packet tunnel target has matching entitlements and is still embedded by the main app target.
- Captured the release flow as an Xcode Organizer task instead of a CLI workflow.
- Switched icon loading to the `Assets.xcassets` `AppIcon` asset and removed the `.icns` dependency from the app and extension project wiring.
- Replaced the menu bar image with the Unicode glyph `⦼` and removed the old image-based menu-bar icon helper.
- Split the menu bar controller into smaller extension files so the controller stays under the file-size target and the responsibilities are easier to follow.

## Verification

- `xcodebuild -project maco.xcodeproj -scheme maco -configuration Release -showBuildSettings` confirmed the Release configuration is using the shared team and hardened runtime.
- An archive attempt showed that Xcode rejects a manually specified `Apple Distribution` identity when automatic signing is enabled, so Release must stay on automatic signing.
- The project file now references the asset catalog for both targets instead of the legacy `AppIcon.icns` resource.
- The menu bar controller now sets the status button title to `⦼` with padding instead of using an image.
- `MenuBarController.swift` is now a coordinator file, with menu actions, menu construction, state handling, and action context split into dedicated files.
- The app and packet-tunnel extension now share the same build number so Xcode's embedded-binary validation passes cleanly.

## Blockers

- App Store upload still depends on the local developer account, provisioning profiles, and any Apple approval required for the Network Extension entitlement.
- TestFlight submission has not been completed yet.

## Next Step

- Finish the archive and upload flow in Xcode Organizer.
