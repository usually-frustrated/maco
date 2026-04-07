# Development Guide

## Prerequisites

- **Xcode 15+** with macOS 14 SDK
- **Homebrew** packages:
  ```
  brew install cmake
  ```
- **Git** (system or Xcode CLI tools)

## First-Time Setup

After cloning, run:

```bash
git submodule update --init
./scripts/build-deps.sh
```

This builds all C++ dependencies into `deps/built/` — it takes a few minutes but only needs to run once (or when deps change).

## Building

Open `maco.xcodeproj` in Xcode and build normally (Cmd+B).

The `macopackettunnel` target has a build phase that checks the built deps exist. If you see:

```
error: Missing libssl.a — run ./scripts/build-deps.sh first
```

just run `./scripts/build-deps.sh` and rebuild.

## C++ Dependencies

All deps are vendored as git submodules under `deps/`:

| Submodule | Purpose |
|-----------|---------|
| `deps/openssl` | TLS — libssl, libcrypto |
| `deps/openvpn3` | OpenVPN3 core (header-only) |
| `deps/asio` | Async I/O (header-only) |
| `deps/fmt` | String formatting |
| `deps/jsoncpp` | JSON parsing |
| `deps/lz4` | Compression |
| `deps/xxhash` | Hashing |

Built artifacts land in `deps/built/` (git-ignored). Rebuild when you pull submodule updates:

```bash
git submodule update
./scripts/build-deps.sh
```

> **Note:** OpenSSL builds in-tree (inside `deps/openssl/`) due to an OpenSSL 3.3.x out-of-tree build bug on macOS. Its generated files (`Makefile`, `configdata.pm`) are suppressed in `git status` via `ignore = dirty` in `.gitmodules`.

## Project Structure

```
maco/                   Main app target (SwiftUI, menu bar)
macopackettunnel/       Network Extension target (C++/Swift, OpenVPN tunnel)
deps/                   Git submodules for C++ deps
deps/built/             Built dep artifacts (not committed)
scripts/
  build-deps.sh         Builds all C++ deps
docs/                   Design assets
```

## Signing & Capabilities

The Network Extension (`macopackettunnel`) requires:
- App Groups entitlement shared with the main app
- `com.apple.developer.networking.networkextension` with `packet-tunnel-provider`
- Both targets signed with the same team

Entitlements are in `macopackettunnel/macopackettunnel.entitlements` and `maco/maco.entitlements`.
