#!/bin/sh
# Build C++ dependencies before Xcode builds the project.
# Skip for test/analyze actions that don't need them.
set -e

case "$CI_XCODEBUILD_ACTION" in
    archive|build) ;;
    *) echo "Skipping deps for action: $CI_XCODEBUILD_ACTION"; exit 0 ;;
esac

"$CI_WORKSPACE/scripts/build-deps.sh"
