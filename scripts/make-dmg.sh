#!/bin/bash
# Build a signed + notarized TermChat.dmg for direct (outside-App-Store) distribution.
#   scripts/make-dmg.sh
# Env overrides:
#   SIGNING_IDENTITY  (default: "Developer ID Application: Spencer Hill (VP38993WK6)")
#   NOTARY_PROFILE    (default: termchat-notary)  — skip notarization with NOTARIZE=0
set -euo pipefail
cd "$(dirname "$0")/.."

SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: Spencer Hill (VP38993WK6)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-termchat-notary}"
NOTARIZE="${NOTARIZE:-1}"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
APP="build/TermChat.app"
DMG="build/TermChat-${VERSION}.dmg"
STAGE="build/dmg-stage"

echo "==> building app (release)"
scripts/make-app.sh release >/dev/null

echo "==> re-signing with: $SIGNING_IDENTITY"
codesign --force --deep --options runtime \
  --entitlements Resources/TermChat.entitlements \
  --timestamp --sign "$SIGNING_IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "==> staging DMG contents"
rm -rf "$STAGE" "$DMG"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> building DMG: $DMG"
hdiutil create -volname "TermChat" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

if [[ "$NOTARIZE" == "1" ]]; then
  echo "==> notarizing (profile: $NOTARY_PROFILE)"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  echo "==> stapling"
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
  echo "==> Gatekeeper assessment"
  spctl -a -t open --context context:primary-signature -vv "$DMG" || true
else
  echo "WARNING: notarization skipped (NOTARIZE=0). DMG will trigger Gatekeeper on other Macs."
fi

echo "✓ $DMG"
