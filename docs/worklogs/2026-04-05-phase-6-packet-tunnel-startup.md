# maco Phase 6: Packet Tunnel Startup Contract

- owner/sub-agent: worker `Mencius`, integrated by main agent
- goal: replace the packet tunnel’s generic stub startup failure with structured provider-payload, profile-config, and credential resolution
- files changed:
  - `macopackettunnel/PacketTunnelProvider.swift`
  - `macopackettunnel/PacketTunnelStartupContext.swift`
  - `macopackettunnel/PacketTunnelStartupError.swift`
  - `maco.xcodeproj/project.pbxproj`
- verification performed:
  - `xcodebuild -project maco.xcodeproj -scheme maco -configuration Debug -sdk macosx -derivedDataPath /tmp/macovpn-derived CODE_SIGNING_ALLOWED=NO build`
- decisions made:
  - the packet tunnel now fails only after it has parsed the saved provider payload and attempted to resolve profile/config/credential inputs
  - saved credentials are required only when the resolved `.ovpn` contains `auth-user-pass`
  - the not-yet-implemented OpenVPN engine remains a distinct final startup error after structured setup succeeds
- blockers or next handoff notes:
  - next slice should own Phase 7 only: integrate `OpenVPN 3 Core` for one real profile connection path through the existing startup context
  - the signed packet tunnel still needs real runtime validation for access to the shared app-group container; if that path is blocked by sandboxing, Phase 7 must stop and document the exact platform constraint
