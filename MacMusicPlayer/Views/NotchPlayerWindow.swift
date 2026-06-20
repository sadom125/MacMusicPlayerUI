import SwiftUI
import AppKit

/// Borderless panel covering the MacBook notch — Dynamic Island style.
class NotchPlayerWindow: NSPanel {
    private let hostingView: NSHostingView<AnyView>

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(playerManager: PlayerManager) {
        let contentView = NotchPlayerView(player: playerManager)

        let hosting = NSHostingView(rootView: AnyView(contentView))
        self.hostingView = hosting

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 34),
            styleMask: [.borderless, .nonactivatingPanel],
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

        // Above menu bar
        self.level = .statusBar

        hosting.frame = NSRect(x: 0, y: 0, width: 200, height: 34)
        hosting.autoresizingMask = [.width, .height]
        self.contentView = hosting

        positionAtNotch(collapsed: true)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleExpandChange(_:)),
            name: NSNotification.Name("NotchPlayerExpandChanged"),
            object: nil
        )
    }

    @objc private func handleExpandChange(_ notification: Notification) {
        guard let expanded = notification.userInfo?["expanded"] as? Bool else { return }
        positionAtNotch(collapsed: !expanded)
    }

    /// Position window at notch. Collapsed = covers notch; expanded = drops down.
    func positionAtNotch(collapsed: Bool = true) {
        guard let screen = NSScreen.main else { return }
        guard screen.safeAreaInsets.top > 0 else {
            self.orderOut(nil)
            return
        }

        let screenFrame = screen.frame
        let notchHeight = screen.safeAreaInsets.top

        // Collapsed: covers notch + extends slightly left/right
        // Expanded: extends downward from notch
        let windowWidth: CGFloat = collapsed ? 200 : 500
        let windowHeight: CGFloat = collapsed ? notchHeight : notchHeight + 90

        let x = screenFrame.midX - windowWidth / 2
        let y = screenFrame.maxY - windowHeight

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.4
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
            self.animator().setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
        }
    }

    override func close() {
        self.animations = [:]
        NotificationCenter.default.removeObserver(self)
        super.close()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
