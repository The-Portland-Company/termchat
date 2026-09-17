import Foundation

/// What the bubble knows about where the selection came from.
public struct TerminalContext: Sendable {
    public var app: String            // "iTerm2", "Terminal", or another bundle name
    public var bundleID: String?
    public var scrollback: String?    // last N lines of the front session
    public var workingDir: String?
    public init(app: String, bundleID: String?, scrollback: String?, workingDir: String?) {
        self.app = app; self.bundleID = bundleID; self.scrollback = scrollback; self.workingDir = workingDir
    }
    public var isTerminal: Bool { bundleID == "com.googlecode.iterm2" || bundleID == "com.apple.Terminal" }

    /// Reads the front session of iTerm2 / Terminal.app via AppleScript (Automation TCC prompt on first use).
    public static func capture(bundleID: String?, appName: String, maxLines: Int = 200) -> TerminalContext {
        var ctx = TerminalContext(app: appName, bundleID: bundleID, scrollback: nil, workingDir: nil)
        switch bundleID {
        case "com.googlecode.iterm2":
            ctx.scrollback = run("""
                tell application "iTerm2" to tell current session of current tab of current window to return contents
                """)
            ctx.workingDir = run("""
                tell application "iTerm2" to tell current session of current tab of current window to return variable named "session.path"
                """)
        case "com.apple.Terminal":
            ctx.scrollback = run("""
                tell application "Terminal" to return contents of selected tab of front window
                """)
            if let tty = run("tell application \"Terminal\" to return tty of selected tab of front window") {
                ctx.workingDir = cwdForTTY(tty)
            }
        default:
            break
        }
        if let s = ctx.scrollback {
            let lines = s.split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            var trimmed = Array(lines.suffix(maxLines))
            while let last = trimmed.last, last.isEmpty { trimmed.removeLast() }
            ctx.scrollback = trimmed.joined(separator: "\n")
        }
        return ctx
    }

    private static func run(_ source: String) -> String? {
        var err: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&err)
        if let err { NSLog("TermChat AppleScript error: \(err)"); return nil }
        let s = result?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (s?.isEmpty ?? true) ? nil : s
    }

    /// Terminal.app exposes the tty; map it to the foreground shell's cwd via lsof.
    private static func cwdForTTY(_ tty: String) -> String? {
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/sh")
        ps.arguments = ["-c", "pid=$(ps -t \(tty.replacingOccurrences(of: "/dev/", with: "")) -o pid=,comm= | grep -E 'zsh|bash|fish' | head -1 | awk '{print $1}'); [ -n \"$pid\" ] && lsof -a -p \"$pid\" -d cwd -Fn | sed -n 's/^n//p'"]
        let pipe = Pipe(); ps.standardOutput = pipe; ps.standardError = FileHandle.nullDevice
        try? ps.run(); ps.waitUntilExit()
        let s = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : s
    }

    /// Insert text at the terminal prompt without running it (iTerm2 only for now).
    @discardableResult
    public static func insert(_ text: String, bundleID: String?) -> Bool {
        guard bundleID == "com.googlecode.iterm2" else { return false }
        let escaped = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return run("""
            tell application "iTerm2" to tell current session of current tab of current window to write text "\(escaped)" newline NO
            return "ok"
            """) != nil
    }
}
