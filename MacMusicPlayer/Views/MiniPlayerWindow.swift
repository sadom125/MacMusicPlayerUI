import SwiftUI
import AppKit

/// Floating mini player panel that sits above all windows.
class MiniPlayerWindow: NSPanel {
    private let hostingView: NSHostingView<AnyView>

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(playerManager: PlayerManager) {
        let contentView = MiniPlayerView(player: playerManager)

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
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.animationBehavior = .none
        self.isReleasedWhenClosed = false

        // Glass background for mini player
        let glass = NSVisualEffectView()
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.isEmphasized = false
        glass.autoresizingMask = [.width, .height]
        glass.frame = self.contentView?.bounds ?? .zero

        // Rounded corners on the panel
        glass.wantsLayer = true
        glass.layer?.cornerRadius = 22
        glass.layer?.masksToBounds = true

        hosting.frame = glass.bounds
        hosting.autoresizingMask = [.width, .height]
        glass.addSubview(hosting)

        self.contentView = glass
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
