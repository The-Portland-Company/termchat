// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TermChat",
    platforms: [.macOS(.v14)],
    targets: [
        // Provider layer (Claude CLI first; Codex/Gemini CLIs later) + terminal readers.
        .target(name: "TermChatCore", path: "Sources/TermChatCore"),
        // Menu-bar app with the floating chat bubble. Bundled by scripts/make-app.sh.
        .executableTarget(name: "TermChat", dependencies: ["TermChatCore"], path: "Sources/TermChat"),
    ]
)
