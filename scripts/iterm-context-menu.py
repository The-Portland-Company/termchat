#!/usr/bin/env python3
"""Add a "💬 Ask TermChat" item to iTerm2's right-click menu (Smart Selection rule on every profile).
Needs: pip install iterm2, and ITERM2_COOKIE / ITERM2_KEY from
  osascript -e 'tell application "iTerm2" to request cookie and key for app named "termchat"'
Idempotent; keeps iTerm's built-in rules."""
import iterm2, asyncio, plistlib
DEFAULTS = list(plistlib.load(open("/Applications/iTerm.app/Contents/Resources/SmartSelectionRules.plist","rb")).values())[0]
TITLE = "💬 Ask TermChat"
RULE = {"regex": r"(?s).+", "notes": "TermChat: ask AI about the selection", "precision": "very_low",
        "actions": [{"title": TITLE, "action": 2, "parameter": r"/Applications/TermChat.app/Contents/Resources/termchat-ask \0"}]}
async def main(connection):
    profiles = await iterm2.PartialProfile.async_query(connection)
    for pp in profiles:
        p = await pp.async_get_full_profile()
        rules = [r for r in (p.smart_selection_rules or []) if r.get("notes") != RULE["notes"]] or list(DEFAULTS)
        rules.insert(0, RULE)
        await p.async_set_smart_selection_rules(rules)
        print("updated:", p.name, "rules:", len(rules))
iterm2.run_until_complete(main)
