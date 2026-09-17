#!/usr/bin/env python3
"""iTerm2 context-menu provider for TermChat.

Registers a right-click ONLY menu item ("💬 Ask TermChat"). Unlike a Smart
Selection *action*, an API context-menu provider is never triggered by
cmd-click, so it leaves link-clicking and every keyboard binding untouched.

Run by scripts/termchat-provider-run.sh under a LaunchAgent. Needs the `iterm2`
pip package and ITERM2_COOKIE / ITERM2_KEY in the environment.
"""
import os
import subprocess
import datetime
import iterm2

LOG = os.path.expanduser("~/Library/Application Support/TermChat/provider.log")


def log(msg):
    try:
        with open(LOG, "a") as f:
            f.write(f"{datetime.datetime.now().isoformat()} {msg}\n")
    except Exception:
        pass

DISPLAY_NAME = os.environ.get("TERMCHAT_MENU_TITLE", "💬 Ask TermChat")
UNIQUE_ID = "com.spencerhill.termchat.ask"
HELPER = "/Applications/TermChat.app/Contents/Resources/termchat-ask"


async def main(connection):
    app = await iterm2.async_get_app(connection)

    @iterm2.ContextMenuProviderRPC
    async def ask_termchat(session_id=iterm2.Reference("id")):
        log(f"invoked session_id={session_id}")
        session = app.get_session_by_id(session_id)
        if session is None:
            log("no session")
            return
        selection = await session.async_get_selection()
        try:
            text = await session.async_get_selection_text(selection)
        except Exception as e:
            log(f"selection err {e}")
            text = ""
        text = (text or "").strip()
        log(f"selection text len={len(text)}")
        if not text:
            return
        subprocess.Popen([HELPER, text])
        log("helper launched")

    await ask_termchat.async_register(connection, DISPLAY_NAME, UNIQUE_ID)
    log(f"registered as {DISPLAY_NAME!r}")


iterm2.run_forever(main)
