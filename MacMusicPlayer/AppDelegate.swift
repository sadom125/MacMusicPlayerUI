import Cocoa
import MediaPlayer


@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var playerManager: PlayerManager!
    var sleepManager: SleepManager!
    var launchManager: LaunchManager!
    var libraryManager: LibraryManager!
    var configManager: ConfigManager!
    var statusMenuController: StatusMenuController!

    private var downloadWindow: NSWindow?
    private var configWindow: NSWindow?
    private var songPickerWindow: SimpleSongPickerWindow?
    private(set) var mainPlayerWindow: MainPlayerWindow?
    var miniPlayerWindow: MiniPlayerWindow?
    var notchPlayerWindow: NotchPlayerWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        playerManager = PlayerManager()
        sleepManager = SleepManager()
        launchManager = LaunchManager()
        libraryManager = LibraryManager()
        configManager = ConfigManager.shared
        DownloadManager.shared.updateLibraryManager(libraryManager)

        if let currentLibrary = libraryManager.currentLibrary {
            playerManager.loadLibrary(currentLibrary)
        } else {
            playerManager.requestMusicFolderAccess()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.target = self
            button.action = #selector(toggleMenu)
        }

        statusMenuController = StatusMenuController(
            playerManager: playerManager,
            sleepManager: sleepManager,
            launchManager: launchManager,
            libraryManager: libraryManager
        )

        if let statusItem = statusItem {
            statusMenuController.configureStatusItem(statusItem, target: self)
        }
        setupRemoteCommandCenter()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAddNewLibrary(_:)),
            name: NSNotification.Name("AddNewLibrary"),
            object: nil
        )

        DispatchQueue.main.async { [weak self] in
            self?.showMainWindow()
            self?.setupNotchPlayer()
        }
    }

    // MARK: - Notch Player (Dynamic Island)

    private func setupNotchPlayer() {
        // Always show notch player on launch
        showNotchPlayer()

        // Observe playback state to show/hide notch player
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playbackStateChanged),
            name: NSNotification.Name("PlaybackStateChanged"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playbackStateChanged),
            name: NSNotification.Name("TrackChanged"),
            object: nil
        )
    }

    @objc private func playbackStateChanged() {
        guard playerManager.currentTrack != nil else {
            notchPlayerWindow?.orderOut(nil)
            return
        }
        // Show notch player when playing
        if playerManager.isPlaying {
            showNotchPlayer()
        } else {
            // Keep visible when paused (user might resume)
            showNotchPlayer()
        }
    }

    func showNotchPlayer() {
        if notchPlayerWindow == nil {
            notchPlayerWindow = NotchPlayerWindow(playerManager: playerManager)
        }
        // Notch player auto-positions itself
        notchPlayerWindow?.orderFront(nil)
    }

    func hideNotchPlayer() {
        notchPlayerWindow?.orderOut(nil)
    }

    func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.playerManager.play()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.playerManager.pause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            if let isPlaying = self?.playerManager.isPlaying {
                if isPlaying {
                    self?.playerManager.pause()
                } else {
                    self?.playerManager.play()
                }
            }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.playerManager.playNext()
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.playerManager.playPrevious()
            return .success
        }
    }

    @objc func toggleMenu() {
        statusMenuController.refresh()
        statusItem?.button?.performClick(nil)
    }

    @objc func togglePlayPause() {
        if playerManager.isPlaying {
            playerManager.pause()
        } else {
            playerManager.play()
        }
    }

    @objc func playPrevious() {
        playerManager.playPrevious()
    }

    @objc func playNext() {
        playerManager.playNext()
    }

    @objc func feelingLucky() {
        playerManager.feelingLucky()
    }

    @objc func quit() {
        NSApplication.shared.terminate(self)
    }
    @objc func togglePreventSleep() {
        sleepManager.preventSleep.toggle()
        statusMenuController.refresh()
    }

    @objc func setPlayMode(_ sender: NSMenuItem) {
        let mode: PlayMode
        switch sender.tag {
        case 0:
            mode = .sequential
        case 1:
            mode = .singleLoop
        case 2:
            mode = .random
        default:
            return
        }
        playerManager.playMode = mode
        statusMenuController.refresh()
    }

    @objc func toggleLaunchAtLogin() {
        launchManager.launchAtLogin.toggle()
        statusMenuController.refresh()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // 1. Remove window content FIRST — this triggers SwiftUI onDisappear,
        //    which stops NSEvent monitors and Timers in MainPlayerView.
        //    Without this, those callbacks hold dangling references during dealloc.
        mainPlayerWindow?.contentView = nil
        miniPlayerWindow?.contentView = nil
        notchPlayerWindow?.orderOut(nil)

        // 2. Save playback position before stopping
        playerManager.savePlaybackPosition()

        // 3. Stop playback and release AVQueuePlayer resources
        playerManager.stopAndCleanup()

        // 4. Remove MPRemoteCommandCenter targets
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)

        // 5. Clear NowPlaying info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

        sleepManager.cleanupResourcesOnly()
    }

    func applicationWillResignActive(_ notification: Notification) {
        playerManager.savePlaybackPosition()
    }

    @objc func togglePlaylist() {
        guard let window = mainPlayerWindow, !window.isZoomed else {
            // Just toggle the storage even when zoomed
            let current = UserDefaults.standard.bool(forKey: "showPlaylist")
            UserDefaults.standard.set(!current, forKey: "showPlaylist")
            return
        }

        let current = UserDefaults.standard.bool(forKey: "showPlaylist")
        let position = UserDefaults.standard.string(forKey: "playlistPosition") ?? "right"
        let newState = !current
        UserDefaults.standard.set(newState, forKey: "showPlaylist")

        let targetWidth: CGFloat = position == "right" ? (newState ? 1180 : 900) : 900
        let targetHeight: CGFloat = position == "bottom" ? (newState ? 900 : 650) : 650
        var frame = window.frame
        frame.size.width = targetWidth
        frame.size.height = targetHeight
        window.setFrame(frame, display: true, animate: false)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    @objc func showDownloadWindow() {
        if let existingWindow = self.downloadWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let downloadVC = DownloadViewController()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = downloadVC
        window.title = NSLocalizedString("Download Music", comment: "")
        window.center()

        window.isReleasedWhenClosed = false
        window.delegate = self

        self.downloadWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func handleAddNewLibrary(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let name = userInfo["name"] as? String,
              let path = userInfo["path"] as? String else {
            return
        }

        libraryManager.addLibrary(name: name, path: path)

        statusMenuController.refresh()
    }

    @objc func switchLibrary(_ sender: NSMenuItem) {
        guard let libraryId = sender.representedObject as? UUID else { return }

        libraryManager.switchLibrary(id: libraryId)

        if let currentLibrary = libraryManager.currentLibrary {
            playerManager.loadLibrary(currentLibrary)
        }

        statusMenuController.refresh()
    }

    @objc func addNewLibrary() {
        playerManager.requestMusicFolderAccess()
    }

    @objc func removeCurrentLibrary() {
        guard libraryManager.libraries.count > 1,
              let currentId = libraryManager.currentLibrary?.id else {
            return
        }

        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Confirm Deletion", comment: "Alert title when deleting a music library")
        alert.informativeText = NSLocalizedString("This operation will not delete music files on disk, it only removes this library from the app.", comment: "Alert description when deleting a music library")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("Delete", comment: "Button title for confirming deletion"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Button title for cancelling deletion"))

        if alert.runModal() == .alertFirstButtonReturn {
            libraryManager.removeLibrary(id: currentId)

            if let newCurrent = libraryManager.currentLibrary {
                playerManager.loadLibrary(newCurrent)
            }

            statusMenuController.refresh()
        }
    }

    @objc func refreshCurrentLibrary() {
        guard let currentLibrary = libraryManager.currentLibrary else { return }

        playerManager.loadLibrary(currentLibrary)
        statusMenuController.showTemporaryRefreshingIcon()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.statusMenuController.updateStatusBarIcon()
        }
    }

    @objc func renameCurrentLibrary() {
        guard let currentLibrary = libraryManager.currentLibrary else { return }

        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Rename Library", comment: "Alert title when renaming a music library")
        alert.informativeText = NSLocalizedString("Please enter a new name for the library:", comment: "Alert description when renaming a music library")
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("OK", comment: "Button title for confirming rename"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Button title for cancelling rename"))

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        textField.stringValue = currentLibrary.name
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newName.isEmpty {
                libraryManager.renameLibrary(id: currentLibrary.id, newName: newName)

                statusMenuController.refresh()
            }
        }
    }

    @objc func showConfigWindow() {
        if let existingWindow = self.configWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let configVC = ConfigViewController {
            NotificationCenter.default.post(name: NSNotification.Name("ConfigUpdated"), object: nil)
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 280),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = configVC
        window.title = NSLocalizedString("Settings", comment: "")
        window.center()

        window.isReleasedWhenClosed = false
        window.delegate = self

        self.configWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showMiniPlayer() {
        if let existing = self.miniPlayerWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Get full player window frame for animation start point
        let sourceFrame = mainPlayerWindow?.frame

        // Create mini player without showing it yet
        let window = MiniPlayerWindow.show(playerManager: playerManager, showWindow: false)
        window.delegate = self
        self.miniPlayerWindow = window

        // Target is the top-right position set by MiniPlayerWindow.show
        let targetFrame = window.frame

        if let sourceFrame = sourceFrame {
            // Start at full window position, invisible
            window.setFrame(sourceFrame, display: false)
            window.alphaValue = 0.0

            // Hide full window first, then animate mini in
            mainPlayerWindow?.orderOut(nil)
            window.orderFront(nil)

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.35
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                ctx.allowsImplicitAnimation = true

                window.animator().setFrame(targetFrame, display: true)
                window.animator().alphaValue = 1.0
            }
        } else {
            window.orderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showMainWindow() {
        if let existingWindow = self.mainPlayerWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = MainPlayerWindow.show(playerManager: playerManager)
        window.delegate = self
        self.mainPlayerWindow = window
    }

    @objc func showSongPickerWindow() {
        if let existingWindow = self.songPickerWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let songPickerWindow = SimpleSongPickerWindow(playerManager: playerManager)
        songPickerWindow.delegate = self

        self.songPickerWindow = songPickerWindow

        songPickerWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showSongPickerIfPreferred() {
        guard configManager.showSongPickerOnLaunch else { return }
        showSongPickerWindow()
    }


}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            if window == downloadWindow {
                downloadWindow = nil
            } else if window == configWindow {
                configWindow = nil
            } else if window == miniPlayerWindow {
                miniPlayerWindow = nil
            } else if window == mainPlayerWindow {
                mainPlayerWindow = nil
            } else if window == songPickerWindow {
                songPickerWindow = nil
            }
        }
    }
}
