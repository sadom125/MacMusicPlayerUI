import SwiftUI
import AppKit

/// Panel that exactly covers the MacBook notch — click to expand.
class NotchPlayerWindow: NSPanel {
    private var expandedState = false
    private weak var playerManager: PlayerManager?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(playerManager: PlayerManager) {
        self.playerManager = playerManager

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 34),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        let binding = Binding<Bool>(
            get: { [weak self] in self?.expandedState ?? false },
            set: { [weak self] value in
                self?.expandedState = value
                self?.updateLayout(expanded: value)
            }
        )

        let hosting = NSHostingView(rootView: AnyView(
            NotchPlayerView(player: playerManager, isExpanded: binding)
        ))

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

        self.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)

        self.contentView = hosting

        positionAtNotch()
    }

    private func updateLayout(expanded: Bool) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        let windowWidth: CGFloat = expanded ? 320 : 220
        let windowHeight: CGFloat = expanded ? 155 : 34

        let x = screenFrame.midX - windowWidth / 2
        let y = screenFrame.maxY - windowHeight

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
        }
    }

    private func positionAtNotch() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let x = screenFrame.midX - 220 / 2
        let y = screenFrame.maxY - 34
        self.setFrame(NSRect(x: x, y: y, width: 220, height: 34), display: false)
    }

    func toggleExpanded() {
        expandedState = !expandedState
        updateLayout(expanded: expandedState)
    }

    override func close() {
        self.animations = [:]
        super.close()
    }
}
