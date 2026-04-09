#!/bin/sh
# Build C++ dependencies before Xcode builds the project.
# Skip for test/analyze actions that don't need them.
set -e

# Print every command so failures are visible in the Xcode Cloud log.
set -x

case "$CI_XCODEBUILD_ACTION" in
    archive|build) ;;
    *) echo "Skipping deps for action: $CI_XCODEBUILD_ACTION"; exit 0 ;;
esac

# Print environment info useful for diagnosing failures.
echo "==> CI_WORKSPACE: $CI_WORKSPACE"
echo "==> Xcode: $(xcodebuild -version | head -1)"
echo "==> macOS: $(sw_vers -productVersion)"
echo "==> arch: $(uname -m)"

# cmake is not pre-installed on Xcode Cloud — install it if missing.
if ! command -v cmake > /dev/null 2>&1; then
    echo "==> cmake not found, installing via Homebrew"
    brew install cmake
fi
echo "==> cmake: $(cmake --version | head -1)"

"$CI_WORKSPACE/scripts/build-deps.sh"
