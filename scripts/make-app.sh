#!/bin/bash
# Build TermChat with SPM, assemble build/TermChat.app, codesign with a stable identity
# (so the Automation TCC grant for iTerm2/Terminal survives rebuilds).
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG="${1:-release}"
APP="build/TermChat.app"

echo "› building ($CONFIG)…"
swift build -c "$CONFIG" --product TermChat 2>&1 | grep -vE '^\[|warning: ' || true
BIN=".build/$CONFIG/TermChat"; [ -x "$BIN" ] || { echo "build failed"; exit 1; }

echo "› assembling ${APP}…"
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TermChat"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp scripts/termchat-ask "$APP/Contents/Resources/termchat-ask"

SIGN_ID="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/{print $2; exit}')"
[ -n "$SIGN_ID" ] || SIGN_ID="-"
echo "› codesigning ($SIGN_ID)…"
codesign --force --options runtime --entitlements Resources/TermChat.entitlements --sign "$SIGN_ID" "$APP"
codesign --verify --verbose "$APP" 2>&1 | sed 's/^/   /'
echo "✓ $APP"
