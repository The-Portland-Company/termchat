# TermChat

Highlight text in **iTerm2** or **Terminal.app** (ex. while Claude Code is running), right-click → **Services → Ask TermChat**, and a floating chat bubble opens next to the selection. It explains the selection using the last ~200 lines of terminal output and the session's working directory as context. The terminal keeps keyboard focus until you click into the bubble. ⎋ closes it.

- **Pointer tail** anchored to where you invoked it; drag the bubble and the tail detaches.
- **Model / effort pickers** in the footer (Claude: fable, opus, sonnet, haiku · low → max).
- **Follow-ups** stay in the same conversation (`claude --resume`).
- **Copy** / **Insert into iTerm** (drops the first backticked command onto your prompt, no Enter).
- Uses the **locally installed `claude` CLI** and its subscription login. No API keys.

## Install

```bash
scripts/install.sh
```

Builds `build/TermChat.app`, signs it, copies it to `/Applications`, installs the Quick Action to `~/Library/Services`, and launches the menu-bar app. First use prompts once for Automation access to iTerm2 / Terminal (reading scrollback).

Optional hotkey: System Settings → Keyboard → Keyboard Shortcuts… → Services → Text → Ask TermChat.

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
| `services/Ask TermChat.workflow` | The Quick Action (Service) |

## Roadmap

- Codex / Gemini CLI providers behind the same `LLMProvider` protocol, provider picker.
- PopClip / Hammerspoon triggers; Terminal.app insert-back.
