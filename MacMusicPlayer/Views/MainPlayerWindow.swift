import SwiftUI
import AppKit

/// NSWindow container holding the SwiftUI MainPlayerView.
class MainPlayerWindow: NSWindow {
    let hostingView: NSHostingView<AnyView>
    private let playerManager: PlayerManager
    private var glassView: NSVisualEffectView?

    init(playerManager: PlayerManager) {
        self.playerManager = playerManager

        let contentView = MainPlayerView(player: playerManager)
            .environment(\.colorScheme, .dark)

        let hosting = NSHostingView(rootView: AnyView(contentView))
        self.hostingView = hosting

        // Check if playlist was open and use expanded width
        let playlistWasOpen = UserDefaults.standard.bool(forKey: "showPlaylist")
        let initialWidth: CGFloat = playlistWasOpen ? 1180 : 900
        let windowRect = NSRect(x: 0, y: 0, width: initialWidth, height: 650)
        super.init(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Initial title based on current track
        updateTitle()

        self.titlebarAppearsTransparent = true
        self.isOpaque = false
        // Use dark background to avoid black flash when app reactivates
        self.backgroundColor = NSColor(red: 0.031, green: 0.031, blue: 0.055, alpha: 1.0)
        self.hasShadow = true

        // Force title text to be visible (white) regardless of background
        self.titleVisibility = .visible
        if let titleView = self.standardWindowButton(.closeButton)?.superview?.superview {
            // The NSTitlebarView will get the visual effect background automatically
        }

        // Glass background — NSVisualEffectView as the window's底层
        let glass = NSVisualEffectView()
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.isEmphasized = false
        glass.autoresizingMask = [.width, .height]
        glass.frame = self.contentView?.bounds ?? .zero
        self.glassView = glass

        // Hosting view sits on top of glass
        hosting.frame = glass.bounds
        hosting.autoresizingMask = [.width, .height]
        glass.addSubview(hosting)

        self.contentView = glass

        // Disable fullscreen to avoid macOS _NSExitFullScreenTransitionController crash.
        // Green button will zoom (maximize) instead of entering fullscreen.
        self.collectionBehavior = [.fullScreenNone]

        // Apply saved window opacity
        let savedOpacity = UserDefaults.standard.double(forKey: "windowOpacity")
        self.alphaValue = CGFloat(savedOpacity > 0 ? savedOpacity : 1.0)

        // Fix: force glass view to re-render when app comes back to foreground.
        // NSVisualEffectView briefly shows black after app reactivation.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        self.center()
        self.acceptsMouseMovedEvents = true
    }

    /// Override to use zoom instead of fullscreen — avoids AppKit fullscreen transition crash.
    override func toggleFullScreen(_ sender: Any?) {
        zoom(sender)
    }

    /// Green button calls zoom: — post notifications to hide/show artwork during animation.
    override func zoom(_ sender: Any?) {
        NotificationCenter.default.post(name: .windowWillZoom, object: nil)
        super.zoom(sender)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NotificationCenter.default.post(name: .windowDidZoom, object: nil)
        }
    }

    /// Force glass view to re-render when app reactivates — fixes black flash.
    @objc private func appDidBecomeActive() {
        // Force immediate synchronous redraw instead of deferred
        glassView?.displayIfNeeded()
        hostingView.displayIfNeeded()
        self.displayIfNeeded()
    }

    /// Update the SwiftUI content without replacing the hosting view (preserves glass background).
    func updateContent(_ view: some View) {
        hostingView.rootView = AnyView(view.environment(\.colorScheme, .dark))
    }

    /// Update window title to show current track name (white text, no artist).
    func updateTitle() {
        if let track = playerManager.currentTrack, !track.title.isEmpty {
            self.title = track.title
        } else {
            self.title = "LX Music"
        }
        // Force dark appearance so title text is white on our custom dark background
        self.appearance = NSAppearance(named: .darkAqua)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension MainPlayerWindow {
    static func show(playerManager: PlayerManager) -> MainPlayerWindow {
        let window = MainPlayerWindow(playerManager: playerManager)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return window
    }
}

extension Notification.Name {
    static let windowWillZoom = Notification.Name("MainPlayerWindowWillZoom")
    static let windowDidZoom = Notification.Name("MainPlayerWindowDidZoom")
}
