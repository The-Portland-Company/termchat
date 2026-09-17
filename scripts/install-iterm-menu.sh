#!/bin/bash
# Installs the "💬 Ask TermChat" right-click item into iTerm2 (all profiles) via the iTerm2 Python API.
set -euo pipefail
cd "$(dirname "$0")/.."
VENV="${TMPDIR:-/tmp}/termchat-venv"
[ -x "$VENV/bin/python" ] || python3 -m venv "$VENV"
"$VENV/bin/pip" install -q iterm2
read -r COOKIE KEY <<<"$(osascript -e 'tell application "iTerm2" to request cookie and key for app named "termchat"')"
ITERM2_COOKIE="$COOKIE" ITERM2_KEY="$KEY" "$VENV/bin/python" scripts/iterm-context-menu.py
