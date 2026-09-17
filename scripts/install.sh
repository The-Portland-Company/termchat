#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/make-app.sh release
pkill -x TermChat 2>/dev/null || true
rm -rf /Applications/TermChat.app
cp -R build/TermChat.app /Applications/TermChat.app
open -a /Applications/TermChat.app
scripts/install-iterm-menu.sh
echo "✓ installed. In iTerm2: select text → right-click → 💬 Ask TermChat."
echo "  Login item: System Settings → General → Login Items → add TermChat."
