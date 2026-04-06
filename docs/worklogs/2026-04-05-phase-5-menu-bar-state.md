# maco Phase 5: Menu Bar Connection Controls And State

- owner/sub-agent: worker `Halley`, integrated by main agent
- goal: add menu bar connect/disconnect actions and surface per-profile `NetworkExtension` connection state
- files changed:
  - `maco/App/MenuBarController.swift`
  - `maco/App/MenuBarStatus.swift`
  - `maco/App/AppNotificationCenter.swift`
  - `maco/VPN/VPNConnectionState.swift`
  - `maco/VPN/SystemVPNConnectionStore.swift`
  - `maco.xcodeproj/project.pbxproj`
- verification performed:
  - `xcodebuild -project maco.xcodeproj -scheme maco -configuration Debug -sdk macosx -derivedDataPath /tmp/macovpn-derived CODE_SIGNING_ALLOWED=NO build`
- decisions made:
  - connection state is tracked per profile through cached `NETunnelProviderManager` instances and `NEVPNStatusDidChange`
  - connect/disconnect notifications are driven by observed status transitions, with synchronous action failures shown immediately
  - failed disconnects are surfaced as an explicit per-profile failed state instead of collapsing directly back to disconnected
- blockers or next handoff notes:
  - next slice should own Phase 6 only: parse the saved provider payload inside the packet tunnel, resolve profile/config identity, load shared credentials, and replace the stub-only startup failure with structured startup errors
  - Phase 6 should verify whether the packet tunnel can actually read the persisted `~/.config/maco/...` paths under the signed sandbox model
