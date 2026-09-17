import AppKit
import SwiftUI

/// Floating, non-activating, borderless bubble with a pointer tail anchored to the
/// selection (the mouse position when the Service fired). Dragging the bubble
/// disconnects the tail. ⎋ closes it. The terminal keeps focus until you click in.
final class BubblePanel: NSPanel {
    static let size = NSSize(width: 440, height: 400)
    static let tailHeight: CGFloat = 12
    private var escMonitor: Any?
    private weak var model: ChatModel?

    init(model: ChatModel) {
        self.model = model
        super.init(contentRect: NSRect(origin: .zero, size: BubblePanel.size),
                   styleMask: [.borderless, .nonactivatingPanel, .utilityWindow],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        level = .floating
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient]   // stays on the desktop it was opened on
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = true
        contentView = NSHostingView(rootView: ChatView(model: model, close: { [weak self] in self?.close() }))
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            if e.keyCode == 53, self?.isKeyWindow == true { self?.close(); return nil }
            return e
        }
    }

    override var canBecomeKey: Bool { true }

    /// A real user drag (not programmatic placement or SwiftUI sizing) detaches the tail.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDragged, model?.tail != .none { model?.disconnectTail() }
        super.sendEvent(event)
    }

    /// Place the bubble so the tail tip sits exactly on `anchor` (screen coords).
    func present(anchor p: NSPoint) {
        let screen = NSScreen.screens.first { NSMouseInRect(p, $0.frame, false) } ?? NSScreen.main
        let vis = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let w = frame.width, h = frame.height
        let below = p.y - h >= vis.minY || p.y - vis.minY > vis.maxY - p.y   // prefer below the selection
        var origin = NSPoint(x: p.x - 40, y: below ? p.y - h : p.y)
        origin.x = min(max(origin.x, vis.minX + 8), vis.maxX - w - 8)
        origin.y = min(max(origin.y, vis.minY + 8), vis.maxY - h - 8)
        let tailX = min(max(p.x - origin.x, 28), w - 28)
        model?.tail = below ? .top : .bottom
        model?.tailX = tailX
        setFrameOrigin(origin)
        orderFrontRegardless()
        makeKey()
    }

    override func close() {
        if let m = escMonitor { NSEvent.removeMonitor(m); escMonitor = nil }
        super.close()
    }
}
