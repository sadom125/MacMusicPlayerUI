import SwiftUI
import AppKit

/// Panel that exactly covers the MacBook notch — click to expand.
class NotchPlayerWindow: NSPanel {
    private let hostingView: NSHostingView<AnyView>
    private var expandedState = false
    private weak var playerManager: PlayerManager?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(playerManager: PlayerManager) {
        self.playerManager = playerManager

        let contentView = NotchPlayerView(player: playerManager, isExpanded: .constant(false))
        let hosting = NSHostingView(rootView: AnyView(contentView))
        self.hostingView = hosting

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 185, height: 32),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        let binding = Binding<Bool>(
            get: { [weak self] in self?.expandedState ?? false },
            set: { [weak self] value in
                self?.expandedState = value
                self?.refreshView()
                self?.updateLayout(expanded: value)
            }
        )
        hostingView.rootView = AnyView(NotchPlayerView(player: playerManager, isExpanded: binding))

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

        self.contentView = hostingView

        positionAtNotch()
    }

    private func refreshView() {
        guard let pm = playerManager else { return }
        let binding = Binding<Bool>(
            get: { [weak self] in self?.expandedState ?? false },
            set: { [weak self] value in
                self?.expandedState = value
                self?.refreshView()
                self?.updateLayout(expanded: value)
            }
        )
        hostingView.rootView = AnyView(NotchPlayerView(player: pm, isExpanded: binding))
    }

    private func updateLayout(expanded: Bool) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        let windowWidth: CGFloat = expanded ? 400 : 185
        let windowHeight: CGFloat = expanded ? 160 : 32

        let x = screenFrame.midX - windowWidth / 2
        let y = screenFrame.maxY - windowHeight

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
            self.animator().setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
        }
    }

    private func positionAtNotch() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let x = screenFrame.midX - 185 / 2
        let y = screenFrame.maxY - 32
        self.setFrame(NSRect(x: x, y: y, width: 185, height: 32), display: false)
    }

    func toggleExpanded() {
        let newState = !expandedState
        expandedState = newState
        refreshView()
        updateLayout(expanded: newState)
    }

    override func close() {
        self.animations = [:]
        super.close()
    }
}
