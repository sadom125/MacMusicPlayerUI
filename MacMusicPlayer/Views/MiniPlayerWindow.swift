import SwiftUI
import AppKit

/// Floating mini player panel that sits above all windows.
class MiniPlayerWindow: NSPanel {
    private let hostingView: NSHostingView<AnyView>

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(playerManager: PlayerManager) {
        let contentView = MiniPlayerView(player: playerManager)
            .environment(\.colorScheme, .dark)

        let hosting = NSHostingView(rootView: AnyView(contentView))
        self.hostingView = hosting

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 150),
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .floating
        self.isMovableByWindowBackground = true
        self.isOpaque = false
        self.backgroundColor = NSColor(red: 0.031, green: 0.031, blue: 0.055, alpha: 0)
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.animationBehavior = .none
        self.isReleasedWhenClosed = false

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
