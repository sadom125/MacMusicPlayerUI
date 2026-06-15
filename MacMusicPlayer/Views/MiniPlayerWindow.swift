import SwiftUI
import AppKit

/// Floating mini player panel that sits above all windows.
class MiniPlayerWindow: NSPanel {
    private let hostingView: NSHostingView<AnyView>

    init(playerManager: PlayerManager) {
        let contentView = MiniPlayerView(player: playerManager)
            .environment(\.colorScheme, .dark)

        let hosting = NSHostingView(rootView: AnyView(contentView))
        self.hostingView = hosting

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 130),
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .floating
        self.isMovableByWindowBackground = true
        self.isOpaque = true
        self.backgroundColor = NSColor(red: 0.031, green: 0.031, blue: 0.055, alpha: 1)
        self.hasShadow = true
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        hosting.frame = self.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        self.contentView = hosting

        // Position bottom-right corner
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = self.frame
            let x = screenFrame.maxX - windowFrame.width - 20
            let y = screenFrame.minY + 40
            self.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}

extension MiniPlayerWindow {
    static func show(playerManager: PlayerManager) -> MiniPlayerWindow {
        let window = MiniPlayerWindow(playerManager: playerManager)
        window.orderFront(nil)
        return window
    }
}
