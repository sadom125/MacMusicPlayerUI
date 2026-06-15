import SwiftUI
import AppKit

/// NSWindow container holding the SwiftUI MainPlayerView.
class MainPlayerWindow: NSWindow {
    private let hostingView: NSHostingView<AnyView>
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

        hosting.frame = self.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        self.contentView = hosting

        self.center()
        self.acceptsMouseMovedEvents = true
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
