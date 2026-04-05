# Phase 5: Menu Bar Connection Controls And State

- owner/sub-agent: worker `Halley`, integrated by main agent
- goal: add menu bar connect/disconnect actions and surface per-profile `NetworkExtension` connection state
- files changed:
  - `MacOVPN/App/MenuBarController.swift`
  - `MacOVPN/App/MenuBarStatus.swift`
  - `MacOVPN/App/AppNotificationCenter.swift`
  - `MacOVPN/VPN/VPNConnectionState.swift`
  - `MacOVPN/VPN/SystemVPNConnectionStore.swift`
  - `MacOVPN.xcodeproj/project.pbxproj`
- verification performed:
  - `xcodebuild -project MacOVPN.xcodeproj -scheme MacOVPN -configuration Debug -sdk macosx -derivedDataPath /tmp/macovpn-derived CODE_SIGNING_ALLOWED=NO build`
- decisions made:
  - connection state is tracked per profile through cached `NETunnelProviderManager` instances and `NEVPNStatusDidChange`
  - connect/disconnect notifications are driven by observed status transitions, with synchronous action failures shown immediately
  - failed disconnects are surfaced as an explicit per-profile failed state instead of collapsing directly back to disconnected
- blockers or next handoff notes:
  - next slice should own Phase 6 only: parse the saved provider payload inside the packet tunnel, resolve profile/config identity, load shared credentials, and replace the stub-only startup failure with structured startup errors
  - Phase 6 should verify whether the packet tunnel can actually read the persisted `~/.config/MacOVPN/...` paths under the signed sandbox model
