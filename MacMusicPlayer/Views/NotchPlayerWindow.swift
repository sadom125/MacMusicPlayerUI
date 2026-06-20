import SwiftUI
import AppKit

/// Borderless panel covering the MacBook notch — Dynamic Island style.
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
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 34),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Now set up the binding that references self
        let binding = Binding<Bool>(
            get: { [weak self] in self?.expandedState ?? false },
            set: { [weak self] value in
                self?.expandedState = value
                self?.refreshView()
                self?.positionAtNotch(collapsed: !value)
            }
        )

        let view = NotchPlayerView(player: playerManager, isExpanded: binding)
        hostingView.rootView = AnyView(view)

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

        self.level = .statusBar

        hostingView.frame = NSRect(x: 0, y: 0, width: 200, height: 34)
        hostingView.autoresizingMask = [.width, .height]
        self.contentView = hostingView

        positionAtNotch(collapsed: true)
        startHoverMonitor()
    }

    private func refreshView() {
        guard let pm = playerManager else { return }
        let binding = Binding<Bool>(
            get: { [weak self] in self?.expandedState ?? false },
            set: { [weak self] value in
                self?.expandedState = value
                self?.refreshView()
                self?.positionAtNotch(collapsed: !value)
            }
        )
        hostingView.rootView = AnyView(NotchPlayerView(player: pm, isExpanded: binding))
    }

    // MARK: - Hover Detection

    private func startHoverMonitor() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            guard let self else { return }
            let mouseLocation = NSEvent.mouseLocation
            let wf = self.frame

            // Close hover zone
            let closeRect = NSRect(
                x: wf.origin.x - 60,
                y: wf.origin.y - 30,
                width: wf.width + 120,
                height: wf.height + 50
            )

            // Far zone (for collapse)
            let farRect = NSRect(
                x: wf.origin.x - 150,
                y: wf.origin.y - 80,
                width: wf.width + 300,
                height: wf.height + 160
            )

            if closeRect.contains(mouseLocation) {
                if !self.expandedState {
                    self.hoverTimer?.invalidate()
                    self.hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: false) { [weak self] _ in
                        DispatchQueue.main.async {
                            self?.setExpanded(true)
                        }
                    }
                }
            } else if !farRect.contains(mouseLocation) && self.expandedState {
                self.hoverTimer?.invalidate()
                self.hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.setExpanded(false)
                    }
                }
            }
        }
    }

    private func setExpanded(_ expanded: Bool) {
        guard expandedState != expanded else { return }
        expandedState = expanded
        refreshView()
        positionAtNotch(collapsed: !expanded)
    }

    // MARK: - Positioning

    func positionAtNotch(collapsed: Bool = true) {
        guard let screen = NSScreen.main else { return }
        guard screen.safeAreaInsets.top > 0 else {
            self.orderOut(nil)
            return
        }

        let screenFrame = screen.frame
        let notchHeight = screen.safeAreaInsets.top

        let windowWidth: CGFloat = collapsed ? 200 : 500
        let windowHeight: CGFloat = collapsed ? notchHeight : notchHeight + 110

        let x = screenFrame.midX - windowWidth / 2
        let y = screenFrame.maxY - windowHeight

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.4
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
            self.animator().setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
        }
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
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        hoverTimer?.invalidate()
    }
}
