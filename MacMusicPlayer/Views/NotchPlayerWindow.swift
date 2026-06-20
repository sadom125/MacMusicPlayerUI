import SwiftUI
import AppKit

/// Full-width panel covering the entire top bar — hides the notch seamlessly.
class NotchPlayerWindow: NSPanel {
    private let hostingView: NSHostingView<AnyView>
    private var expandedState = false
    private var mouseMonitor: Any?
    private var hoverTimer: Timer?
    private weak var playerManager: PlayerManager?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(playerManager: PlayerManager) {
        self.playerManager = playerManager

        let contentView = NotchPlayerView(player: playerManager, isExpanded: .constant(false))
        let hosting = NSHostingView(rootView: AnyView(contentView))
        self.hostingView = hosting

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1512, height: 34),
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

        // Above menu bar level (AXSystemDialog equivalent)
        self.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)

        self.contentView = hostingView

        positionFullScreenWidth()
        startHoverMonitor()
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

    // MARK: - Layout

    /// Collapsed: full-width bar at top, height = notch height
    /// Expanded: extends downward from top
    private func updateLayout(expanded: Bool) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let notchHeight = screen.safeAreaInsets.top

        let windowWidth = screenFrame.width
        let windowHeight: CGFloat = expanded ? notchHeight + 130 : max(notchHeight, 34)

        let x = screenFrame.origin.x
        let y = screenFrame.maxY - windowHeight

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.4
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
            self.animator().setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
        }
    }

    private func positionFullScreenWidth() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let notchHeight = screen.safeAreaInsets.top
        let windowHeight = max(notchHeight, 34)

        self.setFrame(
            NSRect(x: screenFrame.origin.x, y: screenFrame.maxY - windowHeight,
                   width: screenFrame.width, height: windowHeight),
            display: false
        )
    }

    // MARK: - Hover Detection

    private func startHoverMonitor() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            guard let self else { return }
            let loc = NSEvent.mouseLocation
            let wf = self.frame

            // Expand zone: mouse near the top of screen
            let isNearTop = loc.y > wf.origin.y - 30
            let isInHorizontalRange = loc.x >= wf.origin.x && loc.x <= wf.maxX

            if isNearTop && isInHorizontalRange {
                if !self.expandedState {
                    self.hoverTimer?.invalidate()
                    self.hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: false) { [weak self] _ in
                        DispatchQueue.main.async { self?.setExpanded(true) }
                    }
                }
            } else {
                let isFarAway = loc.y < wf.origin.y - 100 || !isInHorizontalRange
                if isFarAway && self.expandedState {
                    self.hoverTimer?.invalidate()
                    self.hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
                        DispatchQueue.main.async { self?.setExpanded(false) }
                    }
                }
            }
        }
    }

    private func setExpanded(_ expanded: Bool) {
        guard expandedState != expanded else { return }
        expandedState = expanded
        refreshView()
        updateLayout(expanded: expanded)
    }

    override func close() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        hoverTimer?.invalidate()
        hoverTimer = nil
        self.animations = [:]
        super.close()
    }

    deinit {
        if let monitor = mouseMonitor { NSEvent.removeMonitor(monitor) }
        hoverTimer?.invalidate()
    }
}
