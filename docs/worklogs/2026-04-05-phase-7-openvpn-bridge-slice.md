# maco Phase 7: OpenVPN Bridge Slice

- owner/sub-agent: main agent
- goal: switch profile storage to a sandbox-readable shared app-group container and land the smallest Objective-C++ OpenVPN bridge plus packet-tunnel lifecycle wiring that compiles
- files changed:
  - `AGENTS.md`
  - `maco/Profiles/ProfilePaths.swift`
  - `maco/Profiles/ProfileStore.swift`
  - `maco/Resources/maco.entitlements`
  - `macopackettunnel/PacketTunnelProvider.swift`
  - `macopackettunnel/OpenVPNPacketTunnelBridge.h`
  - `macopackettunnel/OpenVPNPacketTunnelBridge.mm`
  - `macopackettunnel/Resources/macopackettunnel-Bridging-Header.h`
  - `macopackettunnel/Resources/macopackettunnel.entitlements`
  - `maco.xcodeproj/project.pbxproj`
  - `docs/architecture-locked.md`
  - `docs/implementation-status.md`
  - `docs/implementation-handoff.md`
- verification performed:
  - `env PATH=/opt/zerobrew/bin:$PATH PKG_CONFIG_PATH=/opt/zerobrew/opt/openssl@3/lib/pkgconfig:/opt/zerobrew/opt/fmt/lib/pkgconfig:/opt/zerobrew/opt/jsoncpp/lib/pkgconfig:/opt/zerobrew/opt/lz4/lib/pkgconfig:/opt/zerobrew/opt/xxhash/lib/pkgconfig OPENSSL_ROOT_DIR=/opt/zerobrew/opt/openssl@3 CMAKE_PREFIX_PATH=/opt/zerobrew/opt xcodebuild -project maco.xcodeproj -scheme maco -configuration Debug -sdk macosx -derivedDataPath /tmp/maco-derived CODE_SIGNING_ALLOWED=NO build`
- decisions made:
  - the signed packet tunnel must read profiles from a shared app-group container, so profile storage was moved off the original `~/.config/maco/...` root and legacy data now migrates into the shared container
  - the packet tunnel provider now owns a real bridge object and delegates `setTunnelNetworkSettings` through the bridge rather than returning the stub failure
  - the OpenVPN Core bridge is deliberately minimal and compiles as a single Objective-C++ slice before runtime behavior is finalized
  - the bridge target needed the standalone Asio include path and the packet tunnel target needed the matching C++ and linker flags for the zerobrew OpenVPN/OpenSSL stack
- pivots:
  - started by treating `~/.config/maco/...` access as a hard blocker, then changed storage to an app-group path once that became the clean sandbox-compatible route
  - the first bridge attempt used the wrong OpenVPN callback shape; it was reduced to the actual `TunClient` surface after compile diagnostics showed the mismatch
  - `OpenVPNPacketTunnelBridge.mm` originally relied on the wrong include path for Asio; that was fixed by wiring in `/opt/zerobrew/opt/asio/include`
- blockers or next handoff notes:
  - the bridge compiles, but runtime validation still needs one real OpenVPN 3 Core connection path for one profile
  - the next session should first confirm the packet tunnel can read the imported profile files from the shared app-group container under the signed sandbox model, then finish the real connection path

## Session Update

- verification attempted:
  - reran `xcodebuild` for `macopackettunnel` with the zerobrew environment and `CODE_SIGNING_ALLOWED=NO`; the build still succeeded
  - attempted to stand up a signed sandboxed helper to validate app-group container access for the shared profile path
- outcome:
  - the code path for reading profile files from the shared app-group container remains in place, but signed runtime validation was not completed cleanly in this environment
  - the next slice is still the same: prove the packet tunnel can read `<app-group>/maco/profiles/<UUID>/config.ovpn` at runtime under a signed sandboxed build, then continue the smallest OpenVPN 3 Core connection path for one profile
- blocker:
  - signed packet-tunnel runtime access to the shared app-group container still needs a real launch proof on a signed build; until that is confirmed, do not broaden the bridge surface

## Rename Follow-Up

- the app and project now use the lowercase `maco` name
- the packet tunnel source tree was renamed to the lowercase `macopackettunnel`
- build verification after the rename succeeded with `xcodebuild -project maco.xcodeproj -scheme maco -configuration Debug -sdk macosx -derivedDataPath /tmp/maco-derived CODE_SIGNING_ALLOWED=NO build`
- bundle identifiers, app-group IDs, and keychain access group IDs were left unchanged
