#!/bin/bash
# Install: build → /Applications/TermChat.app, Quick Action → ~/Library/Services, register URL scheme.
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/make-app.sh release
pkill -x TermChat 2>/dev/null || true
rm -rf /Applications/TermChat.app
cp -R build/TermChat.app /Applications/TermChat.app
mkdir -p ~/Library/Services
rm -rf ~/Library/Services/"Ask TermChat.workflow"
cp -R "services/Ask TermChat.workflow" ~/Library/Services/
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/TermChat.app
/System/Library/CoreServices/pbs -update 2>/dev/null || true
open -a /Applications/TermChat.app
echo "✓ installed. Right-click selected text → Services → Ask TermChat."
echo "  Hotkey: System Settings → Keyboard → Keyboard Shortcuts… → Services → Text → Ask TermChat."
echo "  Login item: System Settings → General → Login Items → add TermChat."
