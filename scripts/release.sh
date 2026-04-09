#!/bin/sh
# Build, notarize, and publish a GitHub release from your local machine.
#
# First run: script walks you through one-time credential setup.
# After that: just run ./scripts/release.sh
#
# Usage:
#   ./scripts/release.sh        # auto build number (timestamp)
#   ./scripts/release.sh 42     # explicit build number
set -e

TEAM_ID="5G2TDMV275"
SCHEME="maco"
KEYCHAIN_PROFILE="maco-notary"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/maco.xcodeproj"
WORK="$(mktemp -d)"
BUILD_NUMBER="${1:-$(date +%Y%m%d%H%M)}"

# ── One-time setup ────────────────────────────────────────────────────────────
if ! xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" >/dev/null 2>&1; then
    echo ""
    echo "First-time setup: storing notarization credentials in your keychain."
    echo "You need an App Store Connect API key (or your Apple ID + app-specific password)."
    echo ""
    xcrun notarytool store-credentials "$KEYCHAIN_PROFILE" --team-id "$TEAM_ID"
    echo ""
fi

if ! gh auth status >/dev/null 2>&1; then
    echo "Logging into GitHub CLI..."
    gh auth login
fi

# ── Version ───────────────────────────────────────────────────────────────────
MARKETING=$(xcodebuild \
    -project "$PROJECT" \
    -scheme  "$SCHEME" \
    -configuration Release \
    -showBuildSettings \
    CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" 2>/dev/null \
    | awk '/[[:space:]]MARKETING_VERSION[[:space:]]/{print $3; exit}')

TAG="v${MARKETING}"
ARCHIVE="$WORK/maco.xcarchive"
DMG="$WORK/maco-${MARKETING}.dmg"

echo "==> Release $TAG (build $BUILD_NUMBER)"

# ── Archive ───────────────────────────────────────────────────────────────────
xcodebuild archive \
    -project       "$PROJECT" \
    -scheme        "$SCHEME" \
    -configuration Release \
    -archivePath   "$ARCHIVE" \
    -destination   "generic/platform=macOS" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

# ── Export (Developer ID) ─────────────────────────────────────────────────────
cat > "$WORK/ExportOptions.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>    <string>developer-id</string>
    <key>teamID</key>    <string>${TEAM_ID}</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
    -archivePath        "$ARCHIVE" \
    -exportPath         "$WORK/export" \
    -exportOptionsPlist "$WORK/ExportOptions.plist"

# ── Notarize & staple the .app ────────────────────────────────────────────────
# Zip the .app for submission (notarytool requires a zip/dmg/pkg, not a bare .app).
# Staple the ticket back into the .app before packaging so the DMG works offline.
APP="$WORK/export/maco.app"
ZIP="$WORK/maco-notarize.zip"

ditto -c -k --keepParent "$APP" "$ZIP"

xcrun notarytool submit "$ZIP" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

xcrun stapler staple "$APP"

# ── DMG ───────────────────────────────────────────────────────────────────────
hdiutil create \
    -volname   "maco" \
    -srcfolder "$APP" \
    -ov -format UDZO \
    "$DMG"

# ── GitHub release ────────────────────────────────────────────────────────────
gh release create "$TAG" "$DMG" \
    --title          "maco ${MARKETING}" \
    --generate-notes

echo ""
echo "==> Done: $(gh release view "$TAG" --json url -q .url)"
