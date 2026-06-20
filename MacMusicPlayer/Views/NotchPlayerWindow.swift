import SwiftUI
import AppKit

/// Borderless panel that sits at the MacBook notch area, acting as a Dynamic Island.
class NotchPlayerWindow: NSPanel {
    private let hostingView: NSHostingView<AnyView>

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(playerManager: PlayerManager) {
        let contentView = NotchPlayerView(player: playerManager)

        let hosting = NSHostingView(rootView: AnyView(contentView))
        self.hostingView = hosting

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 40),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovable = false
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.animationBehavior = .none
        self.isReleasedWhenClosed = false

        self.collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle,
        ]

        // Above menu bar level
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)

        hosting.autoresizingMask = [.width, .height]
        self.contentView = hosting

        positionAtNotch()
    }

    /// Calculate notch size and position the window at the top-center of the screen.
    func positionAtNotch() {
        guard let screen = NSScreen.main else { return }
        guard screen.safeAreaInsets.top > 0 else {
            // No notch — hide window
            self.orderOut(nil)
            return
        }

        let screenFrame = screen.frame
        let notchHeight = screen.safeAreaInsets.top

        // Calculate notch width from auxiliary areas
        let leftPadding = screen.auxiliaryTopLeftArea?.width ?? 0
        let rightPadding = screen.auxiliaryTopRightArea?.width ?? 0
        let notchWidth: CGFloat
        if leftPadding > 0 && rightPadding > 0 {
            notchWidth = screenFrame.width - leftPadding - rightPadding
        } else {
            notchWidth = 120 // fallback
        }

        // Window is wider than notch for content, centered
        let windowWidth: CGFloat = max(notchWidth + 80, 260)
        let windowHeight: CGFloat = 40

        let x = screenFrame.midX - windowWidth / 2
        let y = screenFrame.maxY - windowHeight

        self.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: false)
    }

    override func close() {
        self.animations = [:]
        super.close()
    }
}
