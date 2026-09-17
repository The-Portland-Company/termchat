import AppKit

// Menu-bar-only app (LSUIElement in Info.plist). Manual NSApplication bootstrap keeps
// URL handling deterministic: the `termchat://ask` event arrives via the delegate.
@MainActor
func boot() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
MainActor.assumeIsolated { boot() }
