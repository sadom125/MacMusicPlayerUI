import SwiftUI
import AppKit

/// NSWindow container holding the SwiftUI MainPlayerView.
class MainPlayerWindow: NSWindow {
    let hostingView: NSHostingView<AnyView>
    private let playerManager: PlayerManager

    init(playerManager: PlayerManager) {
        self.playerManager = playerManager

        let contentView = MainPlayerView(player: playerManager)
            .environment(\.colorScheme, .dark)

        let hosting = NSHostingView(rootView: AnyView(contentView))
        self.hostingView = hosting

        let windowRect = NSRect(x: 0, y: 0, width: 680, height: 580)
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
        self.backgroundColor = .clear
        self.hasShadow = true

        // Force title text to be visible (white) regardless of background
        self.titleVisibility = .visible
        if let titleView = self.standardWindowButton(.closeButton)?.superview?.superview {
            // The NSTitlebarView will get the visual effect background automatically
        }

        // Glass background — NSVisualEffectView as the window's底层
        let glassView = NSVisualEffectView()
        glassView.material = .hudWindow
        glassView.blendingMode = .behindWindow
        glassView.state = .active
        glassView.isEmphasized = false
        glassView.autoresizingMask = [.width, .height]
        glassView.frame = self.contentView?.bounds ?? .zero

        // Hosting view sits on top of glass
        hosting.frame = glassView.bounds
        hosting.autoresizingMask = [.width, .height]
        glassView.addSubview(hosting)

        self.contentView = glassView

        // Disable fullscreen to avoid macOS _NSExitFullScreenTransitionController crash.
        // Green button will zoom (maximize) instead of entering fullscreen.
        self.collectionBehavior = [.fullScreenNone]

        self.center()
        self.acceptsMouseMovedEvents = true
    }

    /// Override to use zoom instead of fullscreen — avoids AppKit fullscreen transition crash.
    override func toggleFullScreen(_ sender: Any?) {
        zoom(sender)
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
}

extension MainPlayerWindow {
    static func show(playerManager: PlayerManager) -> MainPlayerWindow {
        let window = MainPlayerWindow(playerManager: playerManager)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return window
    }
}
