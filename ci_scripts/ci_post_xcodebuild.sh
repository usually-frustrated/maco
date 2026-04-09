#!/bin/sh
# After the archive action: export, notarize, and publish a GitHub Release.
#
# Required Xcode Cloud environment variables (set as secrets in App Store Connect):
#   ASC_KEY_ID      — App Store Connect API key ID
#   ASC_ISSUER_ID   — App Store Connect issuer ID
#   ASC_KEY_CONTENT — base64-encoded .p8 key file
#   GH_TOKEN        — GitHub fine-grained PAT (contents: write, on this repo)
set -e

[ "$CI_XCODEBUILD_ACTION" = "archive" ] || exit 0

TEAM_ID="5G2TDMV275"
WORK="$(mktemp -d)"

# ── Version ──────────────────────────────────────────────────────────────────
MARKETING=$(xcodebuild \
    -project "$CI_WORKSPACE/maco.xcodeproj" \
    -scheme maco \
    -configuration Release \
    -showBuildSettings \
    CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" 2>/dev/null \
    | awk '/[[:space:]]MARKETING_VERSION[[:space:]]/{print $3; exit}')

TAG="v${MARKETING}-${CI_BUILD_NUMBER}"
DMG="$WORK/maco-${MARKETING}-${CI_BUILD_NUMBER}.dmg"

echo "==> Building release $TAG"

# ── Export archive ────────────────────────────────────────────────────────────
# Xcode Cloud provisions the Developer ID Application certificate automatically
# when the workflow has a "Distribute with Developer ID" action configured.
cat > "$WORK/ExportOptions.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
    -archivePath "$CI_ARCHIVE_PATH" \
    -exportPath  "$WORK/export" \
    -exportOptionsPlist "$WORK/ExportOptions.plist"

# ── Create DMG ────────────────────────────────────────────────────────────────
hdiutil create \
    -volname "maco" \
    -srcfolder "$WORK/export/maco.app" \
    -ov -format UDZO \
    "$DMG"

# ── Notarize ──────────────────────────────────────────────────────────────────
KEY_FILE="$WORK/AuthKey_${ASC_KEY_ID}.p8"
printf '%s' "$ASC_KEY_CONTENT" | base64 --decode > "$KEY_FILE"

xcrun notarytool submit "$DMG" \
    --key       "$KEY_FILE" \
    --key-id    "$ASC_KEY_ID" \
    --issuer    "$ASC_ISSUER_ID" \
    --wait

xcrun stapler staple "$DMG"

# ── GitHub Release via gh CLI ─────────────────────────────────────────────────
brew install gh

# Extract owner/repo from the git remote URL
# Handles both https://github.com/owner/repo.git and git@github.com:owner/repo.git
REPO=$(echo "$CI_GIT_REMOTE_URL" \
    | sed 's|https://github.com/||; s|git@github.com:||; s|\.git$||')

gh release create "$TAG" "$DMG" \
    --repo           "$REPO" \
    --title          "maco ${MARKETING} (build ${CI_BUILD_NUMBER})" \
    --generate-notes
