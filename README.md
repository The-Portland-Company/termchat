# TermChat

Highlight text in **iTerm2** (ex. while Claude Code is running), right-click → **💬 Ask TermChat** (a top-level item in iTerm's own context menu), and a floating chat bubble opens next to the selection. It explains the selection using the last ~200 lines of terminal output and the session's working directory as context. The terminal keeps keyboard focus until you click into the bubble. ⎋ closes it.

- **Pointer tail** anchored to where you invoked it; drag the bubble and the tail detaches.
- **Model / effort pickers** in the footer (Claude: fable, opus, sonnet, haiku · low → max).
- **Follow-ups** stay in the same conversation (`claude --resume`).
- **Copy** / **Insert into iTerm** (drops the first backticked command onto your prompt, no Enter).
- Uses the **locally installed `claude` CLI** and its subscription login. No API keys.

## Install

```bash
scripts/install.sh
```

Builds `build/TermChat.app`, signs it, copies it to `/Applications`, launches the menu-bar app, and adds the **💬 Ask TermChat** item to iTerm2's right-click menu via an iTerm2 API **context-menu provider** (a background LaunchAgent). Because it is a provider and not a Smart Selection action, it appears on **right-click only** — cmd-click still selects/opens links and no keyboard binding is overridden. iTerm2 → Settings → General → Magic → "Enable Python API" must be on.

**Customize the menu title:** edit `~/Library/Application Support/TermChat/config.env` (uncomment/set `TERMCHAT_MENU_TITLE="…"`) and `launchctl kickstart -k gui/$(id -u)/com.spencerhill.termchat.provider`. First use prompts once for Automation access to iTerm2 / Terminal (reading scrollback).

Terminal.app: install `services/Ask TermChat.workflow` into `~/Library/Services` to get it under right-click → Services.

## Test without a terminal selection

```bash
open -g "termchat://ask?text=ECONNREFUSED"
```

## Layout

| Path | What |
| --- | --- |
| `Sources/TermChatCore/LLMProvider.swift` | Provider protocol + `LLMSettings` (model, effort) |
| `Sources/TermChatCore/ClaudeCLIProvider.swift` | `claude -p … --output-format stream-json`, read-only tools |
| `Sources/TermChatCore/TerminalContext.swift` | AppleScript scrollback + cwd readers, insert-into-terminal |
| `Sources/TermChat/` | Menu-bar app, URL handler, bubble panel, SwiftUI chat view |
| `scripts/iterm-provider.py` | iTerm2 API context-menu provider — right-click-only `💬 Ask TermChat` (never fires on cmd-click, overrides no keybinding) |
| `scripts/termchat-provider-run.sh` + `launchagents/*.plist` | LaunchAgent that keeps the provider running while iTerm2 is up |
| `scripts/termchat-ask` | Helper the menu item runs (URL-encodes → `termchat://ask`) |
| `services/Ask TermChat.workflow` | Optional Quick Action for Terminal.app |

## Roadmap

- Codex / Gemini CLI providers behind the same `LLMProvider` protocol, provider picker.
- PopClip / Hammerspoon triggers; Terminal.app insert-back.
