#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEPS="$REPO_ROOT/deps"
BUILD="$DEPS/built"
NCPU=$(sysctl -n hw.ncpu)
DEPLOYMENT_TARGET="14.0"
ARCH=$(uname -m)   # arm64 or x86_64

INTERMEDIATE="$BUILD/intermediate"
mkdir -p "$BUILD" "$INTERMEDIATE"

# ── OpenSSL ────────────────────────────────────────────────────────────────
echo "▸ building openssl"
mkdir -p "$INTERMEDIATE/openssl"
cd "$INTERMEDIATE/openssl"
if [ "$ARCH" = "arm64" ]; then
    OPENSSL_TARGET="darwin64-arm64-cc"
else
    OPENSSL_TARGET="darwin64-x86_64-cc"
fi
"$DEPS/openssl/Configure" "$OPENSSL_TARGET" \
    --prefix="$BUILD" \
    --openssldir="$BUILD/ssl" \
    -mmacosx-version-min="$DEPLOYMENT_TARGET" \
    no-shared no-tests no-docs
make -j"$NCPU"
make install_sw   # skips docs/man pages

# ── CMake deps (fmt, jsoncpp, lz4, xxhash) ────────────────────────────────
cmake_build() {
    local name="$1"; local src="${2:-$DEPS/$name}"; shift 2
    echo "▸ building $name"
    cmake -S "$src" -B "$INTERMEDIATE/$name" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$BUILD" \
        -DBUILD_SHARED_LIBS=OFF \
        "$@" -Wno-dev -DCMAKE_POLICY_DEFAULT_CMP0077=NEW > /dev/null
    cmake --build "$INTERMEDIATE/$name" --parallel "$NCPU"
    cmake --install "$INTERMEDIATE/$name"
}

cmake_build fmt     "$DEPS/fmt"                        -DFMT_TEST=OFF -DFMT_DOC=OFF
cmake_build jsoncpp "$DEPS/jsoncpp"                    -DJSONCPP_WITH_TESTS=OFF -DJSONCPP_WITH_POST_BUILD_UNITTEST=OFF
cmake_build lz4     "$DEPS/lz4/build/cmake"            -DLZ4_BUILD_CLI=OFF
cmake_build xxhash  "$DEPS/xxhash/cmake_unofficial"    -DXXHASH_BUILD_XXHSUM=OFF

echo "✓ all deps built → $BUILD"
