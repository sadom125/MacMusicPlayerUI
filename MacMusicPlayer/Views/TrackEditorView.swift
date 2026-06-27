import SwiftUI

/// Track metadata editor with two states:
///   1. Track picker — search + list all tracks
///   2. Editor form — edit title/artist/album/cover/lyrics
struct TrackEditorView: View {
    @ObservedObject var player: PlayerManager
    @ObservedObject var themeManager = ThemeManager.shared

    // MARK: - State

    /// Picker / Editor mode
    @State private var selectedTrack: Track? = nil

    /// Search query for the track list
    @State private var searchQuery: String = ""

    /// Edited field values
    @State private var editedTitle: String = ""
    @State private var editedArtist: String = ""
    @State private var editedAlbum: String = ""
    @State private var editedArtworkData: Data? = nil
    @State private var editedLyrics: String = ""

    /// UI state
    @State private var isSaving: Bool = false
    @State private var showSaveSuccess: Bool = false
    /// 用户点击了"移除封面"按钮，明确要删除封面
    @State private var removeArtwork: Bool = false
    /// 拖拽文件到歌词区域时高亮
    @State private var isLyricsDropTargeted: Bool = false
    @State private var showSaveError: Bool = false
    @State private var saveErrorMessage: String = ""
    @State private var hasChanges: Bool = false

    // MARK: - Computed

    private var primaryText: Color { themeManager.isDarkMode ? .white : .black }
    private var secondaryText: Color { themeManager.isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6) }
    private var tertiaryText: Color { themeManager.isDarkMode ? .white.opacity(0.35) : .black.opacity(0.35) }
    private var iconColor: Color { themeManager.isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5) }
    private var cardBg: Color { themeManager.isDarkMode ? .white.opacity(0.05) : .black.opacity(0.05) }
    private var rowBg: Color { themeManager.isDarkMode ? .white.opacity(0.03) : .black.opacity(0.03) }
    private var inputBg: Color { themeManager.isDarkMode ? .white.opacity(0.07) : .black.opacity(0.05) }

    private var filteredTracks: [Track] {
        if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            return player.playlist
        }
        let q = searchQuery.lowercased()
        return player.playlist.filter { track in
            track.title.lowercased().contains(q) ||
            track.artist.lowercased().contains(q) ||
            track.album.lowercased().contains(q)
        }
    }

    var body: some View {
        Group {
            if let track = selectedTrack {
                editorForm(track: track)
            } else {
                trackPicker
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Track Picker

    private var trackPicker: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("编辑歌曲信息")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(primaryText)

                Text("选择一首歌曲进行编辑")
                    .font(.system(size: 13))
                    .foregroundColor(secondaryText)
            }

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(tertiaryText)

                TextField("搜索歌曲或歌手...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(primaryText)

                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(tertiaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(inputBg)
            )

            // Track count
            Text("\(filteredTracks.count) 首歌曲")
                .font(.system(size: 12))
                .foregroundColor(tertiaryText)

            // Track list
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 4) {
                    ForEach(Array(filteredTracks.enumerated()), id: \.element.id) { index, track in
                        trackRow(track: track, index: index + 1)
                    }
                }
            }
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 30)
    }

    private func trackRow(track: Track, index: Int) -> some View {
        Button(action: {
            selectTrack(track)
        }) {
            HStack(spacing: 12) {
                // Index
                Text(String(format: "%02d", index))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(tertiaryText)
                    .frame(width: 28, alignment: .trailing)

                // Album art thumbnail
                if let data = track.albumArtData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .interpolation(.low)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(rowBg)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 14))
                                .foregroundColor(tertiaryText)
                        )
                }

                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(primaryText)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if !track.artist.isEmpty {
                            Text(track.artist)
                                .font(.system(size: 12))
                                .foregroundColor(secondaryText)
                                .lineLimit(1)
                        }
                        if !track.album.isEmpty {
                            Text(track.album)
                                .font(.system(size: 11))
                                .foregroundColor(tertiaryText)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                // Edit indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(tertiaryText)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Select Track

    private func selectTrack(_ track: Track) {
        selectedTrack = track
        editedTitle = track.title
        editedArtist = track.artist
        editedAlbum = track.album
        editedArtworkData = track.albumArtData
        editedLyrics = track.lyrics ?? ""
        removeArtwork = false
        hasChanges = false
    }

    // MARK: - Editor Form

    private func editorForm(track: Track) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // Back button + Header
                HStack(spacing: 12) {
                    Button(action: {
                        selectedTrack = nil
                        hasChanges = false
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                            Text("返回列表")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(themeManager.accent)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Track info badge
                    Text(track.url.lastPathComponent)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(tertiaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                // Form fields
                formField(label: "标题", icon: "music.note", value: $editedTitle)
                formField(label: "歌手", icon: "person.fill", value: $editedArtist)
                formField(label: "专辑", icon: "opticaldisc", value: $editedAlbum)

                // Artwork
                artworkSection

                // Lyrics
                lyricsSection(track: track)

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 30)
        }
        .onChange(of: editedTitle) { _ in hasChanges = true }
        .onChange(of: editedArtist) { _ in hasChanges = true }
        .onChange(of: editedAlbum) { _ in hasChanges = true }
        .onChange(of: editedLyrics) { _ in hasChanges = true }
    }

    // MARK: - Form Field

    private func formField(label: String, icon: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(secondaryText)

            TextField("", text: value)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundColor(primaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(inputBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(themeManager.accent.opacity(0.2), lineWidth: 0.5)
                        )
                )
        }
    }

    // MARK: - Artwork Section

    private var artworkSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("封面", systemImage: "photo")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(secondaryText)

            HStack(spacing: 20) {
                // Preview
                if let data = editedArtworkData, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(inputBg)
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 28))
                                .foregroundColor(tertiaryText)
                        )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Button(action: chooseArtwork) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder")
                                .font(.system(size: 12))
                            Text("选择封面图片")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(themeManager.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(themeManager.accent.opacity(0.3), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)

                    if editedArtworkData != nil {
                        Button(action: {
                            editedArtworkData = nil
                            removeArtwork = true
                            hasChanges = true
                        }) {
                            Text("移除封面")
                                .font(.system(size: 12))
                                .foregroundColor(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }

                    Text("支持 JPG / PNG 格式")
                        .font(.system(size: 11))
                        .foregroundColor(tertiaryText)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBg)
            )
        }
    }

    private func chooseArtwork() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.jpeg, .png]
        panel.allowsMultipleSelection = false
        panel.prompt = "选择封面"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let data = try? Data(contentsOf: url) else { return }

        // Limit image size to reasonable dimensions
        if let nsImage = NSImage(data: data) {
            let maxDim: CGFloat = 1200
            if nsImage.size.width > maxDim || nsImage.size.height > maxDim {
                // Resize to max 1200px
                if let resized = resizeImage(nsImage, maxDimension: maxDim) {
                    editedArtworkData = resized
                    hasChanges = true
                    return
                }
            }
        }

        editedArtworkData = data
        removeArtwork = false
        hasChanges = true
    }

    private func resizeImage(_ image: NSImage, maxDimension: CGFloat) -> Data? {
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height)
        guard scale < 1.0 else { return nil }

        let newSize = NSSize(
            width: min(image.size.width * scale, maxDimension),
            height: min(image.size.height * scale, maxDimension)
        )

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let newRect = NSRect(origin: .zero, size: newSize)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(newSize.width),
            pixelsHigh: Int(newSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        bitmap.size = newSize
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: newRect)
        NSGraphicsContext.restoreGraphicsState()

        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    }

    // MARK: - Lyrics Section

    private func lyricsSection(track: Track) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row with label + import button
            HStack {
                Label("歌词", systemImage: "text.quote")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(secondaryText)

                Spacer()

                Button(action: importLrcFile) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 11))
                        Text("导入 LRC 文件")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(themeManager.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(themeManager.accent.opacity(0.3), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .help("选择 LRC 歌词文件导入")
            }

            // Wrap TextEditor + drop catcher in ZStack so the transparent overlay
            // sits above the TextEditor and intercepts file drops even when the
            // user drags directly over the editing area (NSTextView would otherwise
            // swallow the drop and insert the file path as text).
            ZStack {
                TextEditor(text: $editedLyrics)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(primaryText)
                    .padding(12)
                    .frame(minHeight: 200)

                // Transparent drop catcher — sits on top of TextEditor but only
                // responds to drag-drop (not clicks), so text editing still works.
                Color.clear
                    .onDrop(of: [.fileURL], isTargeted: $isLyricsDropTargeted) { providers in
                        handleLrcDrop(providers: providers)
                        return true
                    }

                // Placeholder text when lyrics are empty (non-interactive)
                if editedLyrics.isEmpty {
                    VStack(spacing: 6) {
                        Text("粘贴或输入 LRC 格式歌词...")
                            .font(.system(size: 12))
                            .foregroundColor(isLyricsDropTargeted ? themeManager.accent : tertiaryText)
                        Text("或将 .lrc 文件拖拽到这里")
                            .font(.system(size: 11))
                            .foregroundColor(isLyricsDropTargeted ? themeManager.accent.opacity(0.7) : tertiaryText.opacity(0.7))
                    }
                    .padding(.top, 16)
                    .padding(.leading, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .allowsHitTesting(false)
                }
            }
            // Animated border + background on the entire ZStack
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isLyricsDropTargeted ? themeManager.accent.opacity(0.06) : inputBg)
            )
            .overlay(
                ZStack {
                    // Pulse glow ring when dragging
                    if isLyricsDropTargeted {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(themeManager.accent.opacity(0.25), lineWidth: 3)
                            .scaleEffect(1.02)
                    }
                    // Main border
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isLyricsDropTargeted ? themeManager.accent : inputBg,
                                lineWidth: isLyricsDropTargeted ? 2 : 1)
                }
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isLyricsDropTargeted)

            // Save & Reset buttons
            HStack(spacing: 16) {
                Button(action: {
                    Task { await saveChanges(track: track) }
                }) {
                    HStack(spacing: 6) {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 13))
                        }
                        Text("保存到文件")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(hasChanges ? themeManager.accent : Color.gray.opacity(0.4))
                    )
                }
                .buttonStyle(.plain)
                .disabled(!hasChanges || isSaving)

                Button(action: {
                    selectTrack(track) // Reset to original values
                }) {
                    Text("重置")
                        .font(.system(size: 13))
                        .foregroundColor(secondaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(secondaryText.opacity(0.3), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!hasChanges)

                Spacer()

                // Save result toast
                if showSaveSuccess {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("保存成功")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.green)
                    .transition(.opacity)
                } else if showSaveError {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                        Text("保存失败：\(saveErrorMessage)")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.red)
                    .transition(.opacity)
                }
            }
        }
        // Also catch drops on non-TextEditor areas (header, margins, buttons)
        .onDrop(of: [.fileURL], isTargeted: $isLyricsDropTargeted) { providers in
            handleLrcDrop(providers: providers)
            return true
        }
    }

    // MARK: - LRC Import

    /// Open file picker to select an .lrc file and load its content into the lyrics editor.
    private func importLrcFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.init(filenameExtension: "lrc") ?? .plainText]
        panel.allowsMultipleSelection = false
        panel.prompt = "导入歌词"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadLrcFile(url: url)
    }

    /// Handle drag-and-drop of .lrc or image files onto the lyrics area.
    private func handleLrcDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }

        if provider.canLoadObject(ofClass: NSURL.self) {
            provider.loadObject(ofClass: NSURL.self) { [self] url, error in
                guard let fileURL = url as? URL else { return }
                let ext = fileURL.pathExtension.lowercased()
                DispatchQueue.main.async {
                    if ext == "lrc" {
                        loadLrcFile(url: fileURL)
                    } else if ["jpg", "jpeg", "png", "webp"].contains(ext) {
                        loadArtworkFile(url: fileURL)
                    }
                }
            }
        }
    }

    /// Load an image file and set it as the new cover artwork.
    private func loadArtworkFile(url: URL) {
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer { if shouldStopAccessing { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { return }
        if let nsImage = NSImage(data: data) {
            let maxDim: CGFloat = 1200
            if nsImage.size.width > maxDim || nsImage.size.height > maxDim {
                if let resized = resizeImage(nsImage, maxDimension: maxDim) {
                    editedArtworkData = resized
                    removeArtwork = false
                    hasChanges = true
                    return
                }
            }
        }
        editedArtworkData = data
        removeArtwork = false
        hasChanges = true
    }

    /// Read an .lrc file and fill the lyrics editor.
    private func loadLrcFile(url: URL) {
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer { if shouldStopAccessing { url.stopAccessingSecurityScopedResource() } }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            showSaveErrorMsg("无法读取歌词文件")
            return
        }
        editedLyrics = content
        hasChanges = true
    }

    // MARK: - Save

    private func saveChanges(track: Track) async {
        isSaving = true
        showSaveSuccess = false
        showSaveError = false

        let trimmedTitle = editedTitle.trimmingCharacters(in: .whitespaces)
        let trimmedArtist = editedArtist.trimmingCharacters(in: .whitespaces)
        let trimmedAlbum = editedAlbum.trimmingCharacters(in: .whitespaces)
        let trimmedLyrics = editedLyrics.trimmingCharacters(in: .whitespaces)

        guard !trimmedTitle.isEmpty else {
            showSaveErrorMsg("标题不能为空")
            return
        }

        let originalArtist = track.artist
        let originalAlbum = track.album

        let hasArtworkChanged = editedArtworkData?.hashValue != track.albumArtData?.hashValue
        NSLog("TrackEditor: save - artwork changed: \(hasArtworkChanged), editedArtworkData nil: \(editedArtworkData == nil), original nil: \(track.albumArtData == nil)")

        guard let result = await MetadataWriter.save(
            to: track.url,
            originalTrack: track,
            title: trimmedTitle != track.title ? trimmedTitle : nil,
            artist: trimmedArtist != (originalArtist == "Unknown Artist" ? "" : originalArtist) ? trimmedArtist : nil,
            album: trimmedAlbum != (originalAlbum == "Unknown Album" ? "" : originalAlbum) ? trimmedAlbum : nil,
            artworkData: removeArtwork ? nil : (hasArtworkChanged ? editedArtworkData : nil),
            removeExistingArtwork: removeArtwork,
            lyrics: trimmedLyrics != (track.lyrics ?? "") ? trimmedLyrics : nil
        ) else {
            showSaveErrorMsg("ffmpeg 写入失败，文件可能只读")
            return
        }

        // Update in-memory Track
        let updatedTrack = Track(
            id: track.id,
            title: result.title,
            artist: result.artist,
            album: result.album,
            albumArtData: result.artworkData,
            duration: track.duration,
            url: track.url,
            lyrics: result.lyrics
        )

        await MainActor.run {
            // Update in playlist
            if let idx = player.playlist.firstIndex(where: { $0.id == track.id }) {
                player.playlist[idx] = updatedTrack
            }
            // Update if current track
            if player.currentTrack?.id == track.id {
                player.currentTrack = updatedTrack
                NotificationCenter.default.post(name: .currentTrackMetadataUpdated, object: nil)
            }

            // Update UI state
            selectedTrack = updatedTrack
            editedTitle = updatedTrack.title
            editedArtist = updatedTrack.artist
            editedAlbum = updatedTrack.album
            editedArtworkData = updatedTrack.albumArtData
            editedLyrics = updatedTrack.lyrics ?? ""
            hasChanges = false

            // Show success toast
            isSaving = false
            showSaveSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showSaveSuccess = false
            }
        }
    }

    private func showSaveErrorMsg(_ msg: String) {
        Task { @MainActor in
            saveErrorMessage = msg
            showSaveError = true
            isSaving = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                showSaveError = false
            }
        }
    }
}
