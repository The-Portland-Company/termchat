import Foundation

/// Claude provider: one `claude -p` process per turn, chained with `--resume` so the
/// bubble keeps one conversation. Uses the CLI's own subscription login — no API key.
public final class ClaudeCLIProvider: LLMProvider {
    public let id = "claude"
    public let displayName = "Claude (claude CLI)"
    public let models: [(id: String, label: String)] = [
        ("fable", "Fable 5.1"), ("opus", "Opus"), ("sonnet", "Sonnet"), ("haiku", "Haiku"),
    ]
    public let efforts = ["low", "medium", "high", "xhigh", "max"]

    public static func locate() -> String? {
        let home = NSHomeDirectory()
        let candidates = [
            ProcessInfo.processInfo.environment["TERMCHAT_CLAUDE_PATH"],
            "\(home)/.local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "\(home)/.claude/local/claude",
        ]
        return candidates.compactMap { $0 }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public static let systemPrompt = """
    You are TermChat, a small floating helper next to the user's terminal. The user highlighted \
    text in Terminal.app or iTerm2 (often while running Claude Code) and wants to understand it \
    without leaving their flow. Be concise: lead with the direct answer, then at most a few short \
    bullets. Use the terminal output and working directory when they are provided. You may read \
    files under the working directory to answer accurately, but never modify anything.
    """

    private let claudePath: String
    private var sessionID: String?
    private var process: Process?
    private let queue = DispatchQueue(label: "termchat.claude")

    public init?() {
        guard let p = ClaudeCLIProvider.locate() else { return nil }
        claudePath = p
    }

    public func send(_ prompt: String, workingDir: String?, settings: LLMSettings, onEvent: @escaping (LLMEvent) -> Void) {
        queue.async { [self] in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: claudePath)
            var args = [
                "-p", prompt,
                "--output-format", "stream-json",
                "--include-partial-messages",
                "--verbose",
                "--tools", "Read,Grep,Glob",          // read-only; no Bash/Edit at all
                "--append-system-prompt", ClaudeCLIProvider.systemPrompt,
            ]
            if let m = settings.model, !m.isEmpty { args += ["--model", m] }
            if let e = settings.effort, !e.isEmpty { args += ["--effort", e] }
            if let sid = sessionID { args += ["--resume", sid] }
            p.arguments = args
            let cwd = workingDir.flatMap { FileManager.default.fileExists(atPath: $0) ? $0 : nil }
            p.currentDirectoryURL = URL(fileURLWithPath: cwd ?? NSHomeDirectory())
            // GUI apps get a minimal env; the CLI needs HOME/PATH to find its login + node.
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = [ "\(NSHomeDirectory())/.local/bin", "/opt/homebrew/bin", "/usr/local/bin",
                            env["PATH"] ?? "/usr/bin:/bin" ].joined(separator: ":")
            env["TERMCHAT"] = "1"
            p.environment = env

            let out = Pipe(), err = Pipe()
            p.standardOutput = out
            p.standardError = err
            p.standardInput = FileHandle.nullDevice

            var carry = ""
            var streamed = ""          // text received via deltas
            var sawDelta = false
            var stderrText = ""
            out.fileHandleForReading.readabilityHandler = { [weak self] h in
                let data = h.availableData
                guard !data.isEmpty, let self else { return }
                carry += String(decoding: data, as: UTF8.self)
                while let nl = carry.firstIndex(of: "\n") {
                    let line = String(carry[..<nl]).trimmingCharacters(in: .whitespaces)
                    carry = String(carry[carry.index(after: nl)...])
                    guard !line.isEmpty else { continue }
                    switch StreamEvent.parse(line) {
                    case .initialized(let sid):
                        self.sessionID = sid
                    case .textDelta(let t):
                        sawDelta = true; streamed += t; onEvent(.delta(t))
                    case .textBlock(let t):
                        // Without deltas (older CLI), the full block arrives here.
                        if !sawDelta { streamed += t; onEvent(.delta(t)) }
                    case .toolUse(let name):
                        onEvent(.status("Using \(name)…"))
                    case .finished(let result, let isError):
                        if isError { onEvent(.error(result ?? "Claude returned an error.")) }
                        else { onEvent(.done(result ?? streamed)) }
                    case .other:
                        break
                    }
                }
            }
            err.fileHandleForReading.readabilityHandler = { h in
                stderrText += String(decoding: h.availableData, as: UTF8.self)
            }
            p.terminationHandler = { proc in
                out.fileHandleForReading.readabilityHandler = nil
                err.fileHandleForReading.readabilityHandler = nil
                if proc.terminationStatus != 0 && streamed.isEmpty {
                    let msg = stderrText.trimmingCharacters(in: .whitespacesAndNewlines)
                    onEvent(.error(msg.isEmpty ? "claude exited with status \(proc.terminationStatus)" : msg))
                }
            }
            do { try p.run(); self.process = p }
            catch { onEvent(.error("Could not launch claude: \(error.localizedDescription)")) }
        }
    }

    public func cancel() {
        queue.async { [self] in process?.terminate(); process = nil }
    }
}
