#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEPS="$REPO_ROOT/deps"
BUILD="$DEPS/built"
NCPU=$(sysctl -n hw.ncpu)
DEPLOYMENT_TARGET="14.0"
ARCH=$(uname -m)   # arm64 or x86_64

# Stamp file — re-run by deleting deps/built
STAMP="$BUILD/.built"
if [ -f "$STAMP" ]; then
    echo "deps already built — delete deps/built to rebuild"
    exit 0
fi

mkdir -p "$BUILD"

# ── OpenSSL ────────────────────────────────────────────────────────────────
echo "▸ building openssl"
cd "$DEPS/openssl"
if [ "$ARCH" = "arm64" ]; then
    OPENSSL_TARGET="darwin64-arm64-cc"
else
    OPENSSL_TARGET="darwin64-x86_64-cc"
fi
./Configure "$OPENSSL_TARGET" \
    --prefix="$BUILD" \
    --openssldir="$BUILD/ssl" \
    -mmacosx-version-min="$DEPLOYMENT_TARGET" \
    no-shared no-tests no-docs
make -j"$NCPU"
make install_sw   # skips docs/man pages

# ── CMake deps (fmt, jsoncpp, lz4, xxhash) ────────────────────────────────
cmake_build() {
    local name="$1"; local src="$DEPS/$name"; shift
    echo "▸ building $name"
    cmake -S "$src" -B "$src/build" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$BUILD" \
        -DBUILD_SHARED_LIBS=OFF \
        "$@" -Wno-dev -DCMAKE_POLICY_DEFAULT_CMP0077=NEW > /dev/null
    cmake --build "$src/build" --parallel "$NCPU"
    cmake --install "$src/build"
}

cmake_build fmt      -DFMT_TEST=OFF -DFMT_DOC=OFF
cmake_build jsoncpp  -DJSONCPP_WITH_TESTS=OFF -DJSONCPP_WITH_POST_BUILD_UNITTEST=OFF
cmake_build lz4      -DLZ4_BUILD_CLI=OFF -DLZ4_BUILD_LEGACY_LZ4C=OFF \
                     -S "$DEPS/lz4/build/cmake"
cmake_build xxhash   -DXXHASH_BUILD_XXHSUM=OFF

touch "$STAMP"
echo "✓ all deps built → $BUILD"
