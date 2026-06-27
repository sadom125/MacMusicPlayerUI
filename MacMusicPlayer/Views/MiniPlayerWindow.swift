import SwiftUI
import AppKit

/// Floating mini player panel — capsule design.
class MiniPlayerWindow: NSPanel {
    private let hostingView: NSHostingView<AnyView>

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(playerManager: PlayerManager) {
        let contentView = MiniPlayerView(player: playerManager)

        let hosting = NSHostingView(rootView: AnyView(contentView))
        self.hostingView = hosting

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 110),
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .floating
        self.isMovableByWindowBackground = true
        self.isOpaque = false
        self.backgroundColor = NSColor(white: 0.12, alpha: 0.75)
        self.hasShadow = true
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.animationBehavior = .none
        self.isReleasedWhenClosed = false

        // Rounded corners
        self.contentView?.wantsLayer = true
        self.contentView?.layer?.cornerRadius = 18
        self.contentView?.layer?.masksToBounds = true

        // Drop shadow
        self.contentView?.layer?.shadowColor = NSColor.black.cgColor
        self.contentView?.layer?.shadowOpacity = 0.3
        self.contentView?.layer?.shadowOffset = CGSize(width: 0, height: -2)
        self.contentView?.layer?.shadowRadius = 12

        hosting.frame = self.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        self.contentView = hosting
    }

    override func close() {
        self.animations = [:]
        super.close()
    }
}

extension MiniPlayerWindow {
    static func show(playerManager: PlayerManager, showWindow: Bool = true) -> MiniPlayerWindow {
        let window = MiniPlayerWindow(playerManager: playerManager)
        // Position top-right corner
        if let screen = NSScreen.main {
            let sf = screen.frame
            let w = window.frame.width
            let h = window.frame.height
            let x = sf.maxX - w - 20
            let y = sf.maxY - h - 20
            window.setFrame(NSRect(x: x, y: y, width: w, height: h), display: false)
        }
        if showWindow {
            window.orderFront(nil)
        }
        return window
    }
}
