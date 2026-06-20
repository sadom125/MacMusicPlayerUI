import SwiftUI
import AppKit

/// NSWindow container holding the SwiftUI MainPlayerView.
class MainPlayerWindow: NSWindow {
    let hostingView: NSHostingView<AnyView>
    private let playerManager: PlayerManager

    init(playerManager: PlayerManager) {
        self.playerManager = playerManager

        let contentView = MainPlayerView(player: playerManager)

        let hosting = NSHostingView(rootView: AnyView(contentView))
        self.hostingView = hosting

        // New layout: wider for horizontal album art + lyrics + playlist
        let initialWidth: CGFloat = 1200
        let initialHeight: CGFloat = 750
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
        // Semi-transparent background — glass effect comes from SwiftUI .ultraThinMaterial
        self.backgroundColor = NSColor(white: 0.1, alpha: 0.6)
        self.hasShadow = true

        // Force title text to be visible regardless of background
        self.titleVisibility = .visible

        // Hosting view fills the window directly — no NSVisualEffectView needed
        hosting.frame = self.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        self.contentView = hosting

        // Disable fullscreen to avoid macOS _NSExitFullScreenTransitionController crash.
        // Green button will zoom (maximize) instead of entering fullscreen.
        self.collectionBehavior = [.fullScreenNone]

        // Apply saved window opacity
        let savedOpacity = UserDefaults.standard.double(forKey: "windowOpacity")
        self.alphaValue = CGFloat(savedOpacity > 0 ? savedOpacity : 1.0)

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

    /// Green button calls zoom: — smooth custom animation instead of default zoom.
    override func zoom(_ sender: Any?) {
        NotificationCenter.default.post(name: .windowWillZoom, object: nil)

        if isCurrentlyZoomed {
            // Restore to previous size
            guard let savedFrame = savedFrameBeforeZoom else {
                NotificationCenter.default.post(name: .windowDidZoom, object: nil)
                return
            }

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.4
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                ctx.allowsImplicitAnimation = true
                self.animator().setFrame(savedFrame, display: true)
            } completionHandler: {
                self.isCurrentlyZoomed = false
                NotificationCenter.default.post(name: .windowDidZoom, object: nil)
            }
        } else {
            // Save current frame and zoom to screen size
            savedFrameBeforeZoom = frame

            let screenFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? frame
            let targetFrame = screenFrame

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.4
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                ctx.allowsImplicitAnimation = true
                self.animator().setFrame(targetFrame, display: true)
            } completionHandler: {
                self.isCurrentlyZoomed = true
                NotificationCenter.default.post(name: .windowDidZoom, object: nil)
            }
        }
    }

    /// Custom zoom state tracking
    private var isCurrentlyZoomed: Bool {
        get { objc_getAssociatedObject(self, &AssociatedKeys.isZoomed) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &AssociatedKeys.isZoomed, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Saved frame before zoom for restoring
    private var savedFrameBeforeZoom: NSRect? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.savedFrame) as? NSRect }
        set { objc_setAssociatedObject(self, &AssociatedKeys.savedFrame, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private struct AssociatedKeys {
        static var savedFrame = "savedFrame"
        static var isZoomed = "isZoomed"
    }

    /// Override close to avoid animation-related crashes during dealloc.
    /// Simply disables animations before closing — no view tree manipulation.
    override func close() {
        self.animations = [:]
        super.close()
    }

    /// Update the SwiftUI content without replacing the hosting view.
    func updateContent(_ view: some View) {
        hostingView.rootView = AnyView(view)
    }

    /// Update window title to show current track name (no artist).
    func updateTitle() {
        if let track = playerManager.currentTrack, !track.title.isEmpty {
            self.title = track.title
        } else {
            self.title = "LX Music"
        }
        // Let NSApp.appearance control title bar text color (set by ThemeManager)
    }

}

extension MainPlayerWindow {
    static func show(playerManager: PlayerManager) -> MainPlayerWindow {
        let window = MainPlayerWindow(playerManager: playerManager)

        // Start invisible to avoid flash of solid background before glass renders
        let targetOpacity = window.alphaValue
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Fade in after glass effect has rendered
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().alphaValue = targetOpacity
            }
        }

        return window
    }
}

extension Notification.Name {
    static let windowWillZoom = Notification.Name("MainPlayerWindowWillZoom")
    static let windowDidZoom = Notification.Name("MainPlayerWindowDidZoom")
    static let focusPlaylistSearch = Notification.Name("FocusPlaylistSearch")
    static let clearPlaylistSearch = Notification.Name("ClearPlaylistSearch")
}
