import SwiftUI
import AppKit

/// Borderless panel that sits at the MacBook notch area, acting as a Dynamic Island.
class NotchPlayerWindow: NSPanel {
    private let hostingView: NSHostingView<AnyView>

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(playerManager: PlayerManager) {
        let contentView = NotchPlayerView(player: playerManager)

        let hosting = NSHostingView(rootView: AnyView(contentView))
        self.hostingView = hosting

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 50, height: 34),
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

        hosting.frame = NSRect(x: 0, y: 0, width: 60, height: 30)
        hosting.autoresizingMask = [.width, .height]
        self.contentView = hosting

        positionAtNotch(collapsed: true)

        // Listen for expand/collapse changes
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

    /// Position the window at the notch. Collapsed = small pill, expanded = wider panel.
    func positionAtNotch(collapsed: Bool = true) {
        guard let screen = NSScreen.main else { return }
        guard screen.safeAreaInsets.top > 0 else {
            self.orderOut(nil)
            return
        }

        let screenFrame = screen.frame

        let windowWidth: CGFloat = collapsed ? 60 : 480
        let windowHeight: CGFloat = collapsed ? 30 : 80

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
