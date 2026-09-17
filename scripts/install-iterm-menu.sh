#!/bin/bash
# Installs the right-click "💬 Ask TermChat" item into iTerm2 as an API
# context-menu provider (right-click ONLY — never fires on cmd-click, never
# touches a keyboard binding). Runs as a per-user LaunchAgent with its own venv.
set -euo pipefail
cd "$(dirname "$0")/.."
SUPPORT="$HOME/Library/Application Support/TermChat"
AGENTS="$HOME/Library/LaunchAgents"
LABEL="com.spencerhill.termchat.provider"
PLIST="$AGENTS/$LABEL.plist"
mkdir -p "$SUPPORT" "$AGENTS"

# iTerm2 Python API must be enabled.
if [ "$(defaults read com.googlecode.iterm2 EnableAPIServer 2>/dev/null || echo 0)" != "1" ]; then
  echo "⚠️  Enable it in iTerm2 → Settings → General → Magic → 'Enable Python API', then re-run." >&2
fi

echo "› creating venv…"
[ -x "$SUPPORT/venv/bin/python" ] || python3 -m venv "$SUPPORT/venv"
"$SUPPORT/venv/bin/pip" install -q --upgrade pip iterm2

cp scripts/iterm-provider.py "$SUPPORT/iterm-provider.py"
cp scripts/termchat-provider-run.sh "$SUPPORT/termchat-provider-run.sh"
chmod +x "$SUPPORT/termchat-provider-run.sh"
[ -f "$SUPPORT/config.env" ] || printf '# TermChat config\n# TERMCHAT_MENU_TITLE="💬 Ask TermChat"\n' > "$SUPPORT/config.env"

sed -e "s#__RUN__#$SUPPORT/termchat-provider-run.sh#" \
    -e "s#__LOG__#$SUPPORT/provider.log#" \
    launchagents/$LABEL.plist > "$PLIST"

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
echo "✓ context-menu provider installed (right-click → 💬 Ask TermChat)."
