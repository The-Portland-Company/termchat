import Foundation

/// Events streamed back from a provider for one turn.
public enum LLMEvent: Sendable {
    case delta(String)          // incremental assistant text
    case status(String)         // tool use / progress, shown dimly
    case done(String?)          // final full text (nil if unknown)
    case error(String)
}

/// Per-turn knobs the UI exposes. Nil = provider default.
public struct LLMSettings: Sendable, Equatable {
    public var model: String?
    public var effort: String?
    public init(model: String? = nil, effort: String? = nil) { self.model = model; self.effort = effort }
}

/// One chat provider backed by a locally installed CLI (claude, codex, gemini…).
/// Each provider owns its own conversation state so follow-ups stay coherent.
public protocol LLMProvider: AnyObject {
    var id: String { get }              // "claude", "codex", "gemini"
    var displayName: String { get }
    static func locate() -> String?     // absolute path of the CLI, nil if not installed
    /// Send one user message; stream events until `.done` or `.error`.
    var models: [(id: String, label: String)] { get }
    var efforts: [String] { get }
    func send(_ prompt: String, workingDir: String?, settings: LLMSettings, onEvent: @escaping (LLMEvent) -> Void)
    func cancel()
}
