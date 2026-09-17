import SwiftUI
import AppKit
import TermChatCore

/// Rounded bubble with an optional pointer tail on the top or bottom edge.
struct BubbleShape: Shape {
    var tail: ChatModel.TailEdge
    var tailX: CGFloat
    var radius: CGFloat = 14
    var tailH: CGFloat = BubblePanel.tailHeight
    func path(in r: CGRect) -> Path {
        let body = CGRect(x: r.minX, y: r.minY + (tail == .top ? tailH : 0),
                          width: r.width, height: r.height - (tail == .none ? 0 : tailH))
        var p = Path(roundedRect: body, cornerRadius: radius)
        guard tail != .none else { return p }
        let x = min(max(tailX, radius + 10), r.width - radius - 10)
        var t = Path()
        if tail == .top {          // tip points up (SwiftUI y grows downward)
            t.move(to: CGPoint(x: x - 10, y: body.minY))
            t.addLine(to: CGPoint(x: x, y: r.minY))
            t.addLine(to: CGPoint(x: x + 10, y: body.minY))
        } else {
            t.move(to: CGPoint(x: x - 10, y: body.maxY))
            t.addLine(to: CGPoint(x: x, y: r.maxY))
            t.addLine(to: CGPoint(x: x + 10, y: body.maxY))
        }
        t.closeSubpath()
        p.addPath(t)
        return p
    }
}

struct ChatView: View {
    @ObservedObject var model: ChatModel
    var close: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        let shape = BubbleShape(tail: model.tail, tailX: model.tailX)
        VStack(spacing: 0) {
            header
            Divider()
            transcript
            Divider()
            footer
        }
        .padding(.top, model.tail == .top ? BubblePanel.tailHeight : 0)
        .padding(.bottom, model.tail == .bottom ? BubblePanel.tailHeight : 0)
        .background(.regularMaterial, in: shape)
        .overlay(shape.stroke(.white.opacity(0.12), lineWidth: 1))
        .animation(.easeOut(duration: 0.15), value: model.tail)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal").foregroundStyle(.secondary)
            Text(model.selection.isEmpty ? "TermChat" : model.selection)
                .font(.system(.callout, design: .monospaced)).lineLimit(1).truncationMode(.middle)
            Spacer()
            Text(model.context.app).font(.caption2).foregroundStyle(.tertiary)
            Button(action: close) { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(model.messages) { m in bubble(m).id(m.id) }
                    if model.busy { ProgressView().controlSize(.small).padding(.leading, 4) }
                }
                .padding(12)
            }
            .onChange(of: model.messages.last?.text) { _ in
                if let id = model.messages.last?.id { proxy.scrollTo(id, anchor: .bottom) }
            }
        }
    }

    @ViewBuilder
    private func bubble(_ m: ChatMessage) -> some View {
        switch m.role {
        case .user:
            Text(m.text).font(.callout).padding(8)
                .background(Color.accentColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
        case .assistant:
            Text(LocalizedStringKey(m.text)).font(.callout).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .status:
            Text(m.text).font(.caption).foregroundStyle(.tertiary)
        case .error:
            Text(m.text).font(.caption).foregroundStyle(.red).textSelection(.enabled)
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                TextField("Ask a follow-up…", text: $model.input, axis: .vertical)
                    .textFieldStyle(.roundedBorder).lineLimit(1...4).focused($focused)
                    .onSubmit { model.submit() }
                Button("Send") { model.submit() }
                    .keyboardShortcut(.defaultAction).disabled(model.busy || model.input.isEmpty)
            }
            HStack(spacing: 6) {
                Picker("", selection: $model.model) {
                    Text("Model: default").tag("")
                    ForEach(model.models, id: \.id) { Text($0.label).tag($0.id) }
                }.labelsHidden().controlSize(.small).fixedSize()
                Picker("", selection: $model.effort) {
                    Text("Effort: default").tag("")
                    ForEach(model.efforts, id: \.self) { Text($0).tag($0) }
                }.labelsHidden().controlSize(.small).fixedSize()
                Spacer()
                if let a = model.lastAnswer, !a.isEmpty {
                    Button("Copy") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(a, forType: .string) }
                        .controlSize(.small)
                    if model.canInsert {
                        Button("Insert into iTerm") { _ = Self.insert(a, model: model) }.controlSize(.small)
                    }
                }
            }
        }
        .padding(10)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { focused = true } }
    }

    /// Insert the first backticked line (a command) if present, else the whole answer.
    static func insert(_ text: String, model: ChatModel) -> Bool {
        let cmd = text.split(separator: "\n").map(String.init)
            .first { $0.hasPrefix("`") && $0.hasSuffix("`") }?
            .trimmingCharacters(in: CharacterSet(charactersIn: "`")) ?? text
        return TerminalContext.insert(cmd, bundleID: model.context.bundleID)
    }
}
