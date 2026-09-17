import AppKit
import TermChatCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var bubble: BubblePanel?
    /// Last app the user was in before us. `open termchat://` can make us frontmost for a
    /// moment, so NSWorkspace.frontmostApplication is not reliable at URL-open time.
    private var lastOtherApp: NSRunningApplication?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Register for termchat:// before the first URL event can arrive.
        NSAppleEventManager.shared().setEventHandler(
            self, andSelector: #selector(handleURLEvent(_:reply:)),
            forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        lastOtherApp = NSWorkspace.shared.frontmostApplication
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            guard let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            MainActor.assumeIsolated { self?.lastOtherApp = app }
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "bubble.left.and.text.bubble.right",
                                           accessibilityDescription: "TermChat")
        let menu = NSMenu()
        menu.addItem(withTitle: "Ask about clipboard…", action: #selector(askClipboard), keyEquivalent: "")
        menu.addItem(.separator())
        let provider = ClaudeCLIProvider.locate().map { "Claude CLI: \($0)" } ?? "Claude CLI not found"
        let info = menu.addItem(withTitle: provider, action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit TermChat", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    // MARK: termchat://ask?text=…

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let s = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: s) else { return }
        open(url)
    }

    private func open(_ url: URL) {
        guard url.host == "ask" else { return }
        let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let text = q.first { $0.name == "text" }?.value ?? ""
        // Capture the source app NOW: the Service ran while the terminal was frontmost and we
        // never activate, so this is still the terminal.
        var front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier == Bundle.main.bundleIdentifier || front == nil { front = lastOtherApp }
        let bundleID = front?.bundleIdentifier
        let appName = front?.localizedName ?? "unknown"
        let mouse = NSEvent.mouseLocation

        DispatchQueue.global(qos: .userInitiated).async {
            let ctx = TerminalContext.capture(bundleID: bundleID, appName: appName)
            DispatchQueue.main.async { self.show(selection: text, context: ctx, at: mouse) }
        }
    }

    @objc private func askClipboard() {
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        let ctx = TerminalContext(app: "clipboard", bundleID: nil, scrollback: nil, workingDir: nil)
        show(selection: text, context: ctx, at: NSEvent.mouseLocation)
    }

    private func show(selection: String, context: TerminalContext, at point: NSPoint) {
        bubble?.close()
        guard let provider = ClaudeCLIProvider() else {
            let a = NSAlert(); a.messageText = "Claude CLI not found"
            a.informativeText = "Install Claude Code (`claude`) in ~/.local/bin or /opt/homebrew/bin, or set TERMCHAT_CLAUDE_PATH."
            a.runModal(); return
        }
        let model = ChatModel(provider: provider, selection: selection, context: context)
        let panel = BubblePanel(model: model)
        panel.present(anchor: point)
        bubble = panel
        // No auto-prompt: the bubble opens quietly with the selection attached as
        // context; the user types their own first question. Context (selection,
        // cwd, scrollback) is still prepended to that first turn by ChatModel.
    }
}
