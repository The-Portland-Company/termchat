import Foundation
import TermChatCore

struct ChatMessage: Identifiable {
    enum Role { case user, assistant, status, error }
    let id = UUID()
    var role: Role
    var text: String
}

@MainActor
final class ChatModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var input = ""
    @Published var busy = false
    @Published var model: String { didSet { UserDefaults.standard.set(model, forKey: "model") } }
    @Published var effort: String { didSet { UserDefaults.standard.set(effort, forKey: "effort") } }
    /// Pointer tail: connected to the selection until the bubble is dragged.
    @Published var tail: TailEdge = .none
    @Published var tailX: CGFloat = 40
    enum TailEdge { case none, top, bottom }
    let selection: String
    let context: TerminalContext
    private let provider: LLMProvider
    private var firstTurn = true

    init(provider: LLMProvider, selection: String, context: TerminalContext) {
        self.provider = provider; self.selection = selection; self.context = context
        self.model = UserDefaults.standard.string(forKey: "model") ?? ""
        self.effort = UserDefaults.standard.string(forKey: "effort") ?? ""
    }
    var models: [(id: String, label: String)] { provider.models }
    var efforts: [String] { provider.efforts }
    func disconnectTail() { tail = .none }

    var providerName: String { provider.displayName }
    var canInsert: Bool { context.bundleID == "com.googlecode.iterm2" }
    var lastAnswer: String? { messages.last { $0.role == .assistant }?.text }

    /// Opening turn: explain the selection using terminal context.
    func start() {
        guard !selection.isEmpty else { return }
        send(userVisible: "Explain: \(selection.prefix(120))\(selection.count > 120 ? "…" : "")",
             prompt: "Explain what this means and what to do about it, briefly.")
    }

    func submit() {
        let q = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !busy else { return }
        input = ""
        send(userVisible: q, prompt: q)
    }

    private func send(userVisible: String, prompt: String) {
        messages.append(ChatMessage(role: .user, text: userVisible))
        messages.append(ChatMessage(role: .assistant, text: ""))
        busy = true
        let idx = messages.count - 1
        provider.send(firstTurn ? Self.compose(question: prompt, selection: selection, ctx: context) : prompt,
                      workingDir: context.workingDir,
                      settings: LLMSettings(model: model.isEmpty ? nil : model, effort: effort.isEmpty ? nil : effort)) { [weak self] ev in
            Task { @MainActor in
                guard let self else { return }
                switch ev {
                case .delta(let t): self.messages[idx].text += t
                case .status(let s): self.messages.insert(ChatMessage(role: .status, text: s), at: idx)
                case .done(let full):
                    if let full, self.messages[idx].text.isEmpty { self.messages[idx].text = full }
                    self.busy = false
                case .error(let e):
                    self.messages.append(ChatMessage(role: .error, text: e)); self.busy = false
                }
            }
        }
        firstTurn = false
    }

    private static func compose(question: String, selection: String, ctx: TerminalContext) -> String {
        var s = "The user highlighted this text in \(ctx.app):\n\n```\n\(selection)\n```\n\n"
        if let cwd = ctx.workingDir { s += "Working directory: \(cwd)\n\n" }
        if let sb = ctx.scrollback, !sb.isEmpty {
            s += "Recent terminal output (most recent last):\n\n```\n\(sb)\n```\n\n"
        }
        s += question
        return s
    }
}
