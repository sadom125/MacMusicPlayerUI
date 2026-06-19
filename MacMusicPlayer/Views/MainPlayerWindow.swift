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

        // Check if playlist was open and use expanded size based on position
        let playlistWasOpen = UserDefaults.standard.bool(forKey: "showPlaylist")
        let playlistPosition = UserDefaults.standard.string(forKey: "playlistPosition") ?? "right"
        let initialWidth: CGFloat = playlistWasOpen && playlistPosition == "right" ? 1180 : 900
        let initialHeight: CGFloat = playlistWasOpen && playlistPosition == "bottom" ? 900 : 650
        let windowRect = NSRect(x: 0, y: 0, width: initialWidth, height: initialHeight)
        super.init(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Disable ALL window animations to avoid _NSWindowTransformAnimation dealloc crash
        self.animationBehavior = .none
        self.isReleasedWhenClosed = false

        // Initial title based on current track
        updateTitle()

        self.titlebarAppearsTransparent = true
        self.isOpaque = false
        // Use dark background to avoid black flash when app reactivates
        self.backgroundColor = NSColor(red: 0.031, green: 0.031, blue: 0.055, alpha: 1.0)
        self.hasShadow = true

        // Force title text to be visible (white) regardless of background
        self.titleVisibility = .visible

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

    // MARK: - Keyboard Shortcuts

    /// Check if a text input field is currently the first responder.
    /// When true, text-input keys (Space, arrows) are passed through instead of handled as shortcuts.
    private var isEditingText: Bool {
        firstResponder is NSTextView
    }

    /// Resign first responder when clicking outside the search field,
    /// otherwise keyboard shortcuts remain blocked by the stuck focus.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown || event.type == .rightMouseDown {
            if isEditingText, let contentView = self.contentView {
                let point = contentView.convert(event.locationInWindow, from: nil)
                if let hitView = contentView.hitTest(point) {
                    let isTextField = hitView is NSTextView || hitView.superview is NSTextView
                    if !isTextField {
                        self.makeFirstResponder(nil)
                    }
                }
            }
        }
        super.sendEvent(event)
    }

    /// Handle non-Command keys: Space (play/pause), arrows (seek/volume), Escape (dismiss search).
    override func keyDown(with event: NSEvent) {
        // If a text field is editing, let it handle keyboard input normally
        if isEditingText {
            switch Int(event.keyCode) {
            case 53:  // Escape — dismiss keyboard focus or clear search
                self.makeFirstResponder(nil)
                NotificationCenter.default.post(name: .clearPlaylistSearch, object: nil)
                return
            default:
                super.keyDown(with: event)
                return
            }
        }

        switch Int(event.keyCode) {
        case 49:  // Space — play/pause
            playerManager.togglePlayPause()

        case 123:  // Left arrow — seek backward 10s
            playerManager.seek(by: -10)

        case 124:  // Right arrow — seek forward 10s
            playerManager.seek(by: 10)

        case 125:  // Down arrow — volume down
            playerManager.volumeDown()

        case 126:  // Up arrow — volume up
            playerManager.volumeUp()

        case 53:  // Escape — no action when not editing
            break

        default:
            super.keyDown(with: event)
        }
    }

    /// Handle Command-key shortcuts: ⌘← (previous), ⌘→ (next), ⌘F (search), ⌘L (toggle playlist).
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Only respond when Command is the only primary modifier (not Cmd+Shift etc.)
        guard event.modifierFlags.contains(.command),
              !event.modifierFlags.contains(.shift),
              !event.modifierFlags.contains(.option),
              !event.modifierFlags.contains(.control) else {
            return super.performKeyEquivalent(with: event)
        }

        switch Int(event.keyCode) {
        case 123:  // ⌘← — previous track
            playerManager.playPrevious()
            return true

        case 124:  // ⌘→ — next track
            playerManager.playNext()
            return true

        case 3:    // ⌘F — focus search field
            NotificationCenter.default.post(name: .focusPlaylistSearch, object: nil)
            return true

        case 37:   // ⌘L — toggle playlist
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                appDelegate.togglePlaylist()
            }
            return true

        default:
            return super.performKeyEquivalent(with: event)
        }
    }

    /// Override to use zoom instead of fullscreen — avoids AppKit fullscreen transition crash.
    override func toggleFullScreen(_ sender: Any?) {
        zoom(sender)
    }

    /// Green button calls zoom: — post notifications to hide/show artwork during animation.
    override func zoom(_ sender: Any?) {
        NotificationCenter.default.post(name: .windowWillZoom, object: nil)
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        super.zoom(sender)
        NSAnimationContext.endGrouping()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NotificationCenter.default.post(name: .windowDidZoom, object: nil)
        }
    }

    /// Override close to avoid animation-related crashes during dealloc.
    /// Simply disables animations before closing — no view tree manipulation.
    override func close() {
        self.animations = [:]
        super.close()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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
    static let focusPlaylistSearch = Notification.Name("FocusPlaylistSearch")
    static let clearPlaylistSearch = Notification.Name("ClearPlaylistSearch")
}
