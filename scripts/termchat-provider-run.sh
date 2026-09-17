#!/bin/bash
# Keeps the TermChat iTerm2 context-menu provider connected. Launched by the
# LaunchAgent com.spencerhill.termchat.provider. Re-requests an API cookie each
# time iTerm2 comes up (cookies die with iTerm), so it survives iTerm restarts
# without any approval prompt. Reads an optional custom menu title from config.
set -u
SUPPORT="$HOME/Library/Application Support/TermChat"
VENV="$SUPPORT/venv"
PROVIDER="$SUPPORT/iterm-provider.py"
CONFIG="$SUPPORT/config.env"

while true; do
  if pgrep -x iTerm2 >/dev/null 2>&1; then
    [ -f "$CONFIG" ] && . "$CONFIG"
    CK="$(osascript -e 'tell application "iTerm2" to request cookie and key for app named "com.spencerhill.termchat"' 2>/dev/null)"
    C="${CK%% *}"; K="${CK#* }"
    if [ -n "$C" ] && [ "$C" != "$CK" ]; then
      ITERM2_COOKIE="$C" ITERM2_KEY="$K" TERMCHAT_MENU_TITLE="${TERMCHAT_MENU_TITLE:-💬 Ask TermChat}" \
        "$VENV/bin/python" "$PROVIDER"
    fi
  fi
  sleep 5
done
