# Phase 4: System VPN Configuration Layer

- owner/sub-agent: worker `Socrates`, integrated by main agent
- goal: add the app-side `NETunnelProviderManager` layer that keeps one saved system VPN configuration per imported profile
- files changed:
  - `MacOVPN/App/MenuBarController.swift`
  - `MacOVPN/VPN/SystemVPNConfigurationStore.swift`
  - `MacOVPN/VPN/VPNProviderPayload.swift`
  - `MacOVPN.xcodeproj/project.pbxproj`
- verification performed:
  - `xcodebuild -project MacOVPN.xcodeproj -scheme MacOVPN -configuration Debug -sdk macosx -derivedDataPath /tmp/macovpn-derived CODE_SIGNING_ALLOWED=NO build`
- decisions made:
  - provider managers are owned by this app via explicit provider-configuration keys instead of inferred naming
  - the provider payload stays plain property-list data and carries profile UUID plus the resolved profile directory and config paths
  - reconciliation runs from the app on launch and after profile import or removal; no new UI surface was added in this slice
- blockers or next handoff notes:
  - next slice should own Phase 5 only: add menu bar connect/disconnect actions, observe `NEVPNConnection` status, and surface per-profile state
  - Phase 6 should validate whether the packet tunnel can read the current `~/.config/MacOVPN/...` paths directly under the signed sandbox model
