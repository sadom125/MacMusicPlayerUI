# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LX Music macOS Client — a native macOS music player forked from [samzong/MacMusicPlayer](https://github.com/samzong/MacMusicPlayer), refactored into an immersive lyrics-focused player with a "Dark Immersion" UI.

- **Language:** Swift, ~8,000 lines
- **Framework:** SwiftUI + AppKit (NSHostingView), no external dependencies
- **Platform:** macOS 12.0+ (Monterey)
- **Build system:** Xcode project + Makefile

## Build & Run

The Xcode project lives in `MacMusicPlayer/`. All commands run from that directory.

```bash
# Quick dev build + run
cd MacMusicPlayer
xcodebuild -project MacMusicPlayer.xcodeproj \
  -scheme MacMusicPlayer \
  -derivedDataPath /tmp/MacMusicPlayerDerivedData \
  -destination "platform=macOS" build
open /tmp/MacMusicPlayerDerivedData/Build/Products/Debug/MacMusicPlayer.app
```

**Makefile targets** (from `MacMusicPlayer/`):

| Command | What it does |
|---------|-------------|
| `make build` | Release build for current architecture |
| `make install-app` | Build → copy to `~/Applications` → launch |
| `make dmg` | Self-signed DMGs for x86_64 and arm64 |
| `make clean` | Remove build artifacts |
| `make version` | Print version/git info |
| `make help` | List all targets |

Override version: `MARKETING_SEMVER=1.2.3 make build`

There are **no tests** and **no linter** configured.

## Architecture

### Entry Point & Lifecycle

`MacMusicPlayerApp.swift` → `@NSApplicationDelegateAdaptor(AppDelegate.self)` hands all lifecycle to `AppDelegate`. The SwiftUI `App` body is empty (`Settings { EmptyView() }`) — the app runs via custom `NSWindow`s and an `NSStatusItem` menu bar icon.

`AppDelegate.swift` is the true coordinator: creates all managers, sets up the status menu, configures `MPRemoteCommandCenter` for media keys, then calls `showMainWindow()`.

### Data Flow

```
File system scan → Track placeholder (filename parsed)
    → async MetadataParser.parse() → Track updated with real ID3/Vorbis data
    → PlayerManager (@Published) → MainPlayerView observes & renders
```

`PlayerManager` is the single source of truth — an `ObservableObject` with `@Published` properties for playlist, current track, playback state, time, and duration. All views observe it.

### Key Managers

| Manager | Responsibility |
|---------|---------------|
| `PlayerManager` | Playlist, playback control, seek, NowPlaying integration, async metadata dispatch, volume control |
| `QueuePlayerController` | AVQueuePlayer wrapper with KVO for play/pause/stop/seek, DSD→PCM conversion via ffmpeg |
| `MetadataParser` | AVAsset metadata extraction + synchronous FLAC byte scanning for lyrics/artwork + ffmpeg metadata for DFF/DSF |
| `LibraryManager` | Multiple music library support (folder selection, switching) |
| `PlaylistStore` | Playlist persistence (JSON) |
| `ConfigManager` | UserDefaults-backed settings |
| `ThemeManager` | ObservableObject for theme switching (accent color, theme name) |

### Views Structure

| View | Role |
|------|------|
| `MainPlayerWindow` | NSWindow container (900×650, expandable to 1180 for playlist, transparent titlebar, dark aqua appearance) |
| `MainPlayerView` | Core UI: background + lyrics + 2-row control bar + playlist panel |
| `MiniPlayerWindow` / `MiniPlayerView` | Floating mini player (300×150) |
| `Components/AlbumArtBackground` | Full-bleed album art or solid color background with breathing glow |
| `Components/LyricsView` | Timed lyrics scrolling with 3-tier transparency (past/near/active) + breathing glow |
| `Components/ProgressSlider` | Draggable progress bar with glass thumb + breathing glow |
| `Components/PlaylistPanel` | Right-side or bottom panel with search box, extends to title bar, no independent background |

### Theme System

`Theme/Theme.swift` — `PlayerTheme` enum with 5 accent color themes:
- Blue (#60b0ff), Green (#4ade80), Purple (#a78bfa), Pink (#f472b6), Black (#888888)
- `ThemeManager` (ObservableObject) manages current theme, stored in UserDefaults
- All views use `@ObservedObject var themeManager = ThemeManager.shared` for reactive updates
- Theme cycle button in control bar (colored circle)

### Background Modes

Stored in `@AppStorage("bgMode")`, options:
- `none` — No background, system default glass
- `albumArt` — Show album cover art
- `solid:#hex` — Solid color background (Dark, Navy, Purple, Gray, Teal)

### User Settings

| Setting | Storage | Default |
|---------|---------|---------|
| `bgMode` | @AppStorage | `albumArt` |
| `playerTheme` | UserDefaults | `blue` |
| `windowOpacity` | @AppStorage | `1.0` |
| `showPlaylist` | @AppStorage | `false` |
| `playlistPosition` | @AppStorage | `right` (right/bottom) |
| `SavedVolume` | UserDefaults | `0.3` |

## Features

### UI Controls (2-row layout)
**Top row:** Progress bar with time display (current time — progress — duration)
**Bottom row (left to right):**
1. Playback controls (prev/play/next)
2. Play mode toggle (sequential/singleLoop/random)
3. Background mode picker (dropdown: 无背景/专辑封面/5种纯色)
4. Theme toggle (cycle: 蓝→绿→紫→粉→黑)
5. Volume control (icon + slider, Apple Music style)
6. Window opacity slider (30%~100%)
7. Playlist menu (dropdown: 显示/隐藏播放列表, 右侧显示, 底部显示)
8. Mini player switch

### Playlist Panel
- Right-side panel (260px) or bottom panel (250px height)
- Position toggle via dropdown menu (right/bottom)
- Search box for filtering by song title or artist
- Extends from title bar to window bottom (no independent background)
- Window expands when opened (right: 900→1180 width, bottom: 650→900 height)
- State persisted in `@AppStorage("showPlaylist")` and `@AppStorage("playlistPosition")`
- Respects maximized state (no resize when zoomed)

### Visual Effects
- **Breathing glow** on progress bar fill, thumb shadow, and active lyrics (3s easeInOut cycle)
- **Glass thumb** on progress slider with `.ultraThinMaterial`
- **Album art background** with radial gradient glow overlay
- **Bottom gradient fade** on background for text readability
- **Window zoom handling** — artwork destroyed during zoom, recreated after

### Auto-hide Controls
- Controls auto-hide after 3 seconds of mouse inactivity during playback
- Moving mouse restores controls
- Uses `NSEvent.addLocalMonitorForEvents` + periodic `Timer`

## Lyrics Loading (5-tier fallback)

```
1. External .lrc file (track.url → .lrc)
2. Embedded LYRICS metadata tag (async AVAsset)
3. Synchronous FLAC byte scan (parseLyricsDirect)
4. ffmpeg metadata extraction (DFF/DSF files)
5. Track info display (title/artist/album)
```

## Audio Format Support

**Native formats (AVQueuePlayer):**
- MP3, M4A, WAV, AAC, FLAC, OGG, AIFF

**DSD formats (ffmpeg conversion):**
- DFF, DSF — Real-time conversion to WAV (PCM 16-bit) via ffmpeg
- ffmpeg extracts metadata (title/artist/album/lyrics/artwork) for DSD files

## Cover Art Loading (3-tier fallback)

```
1. Track.albumArtData (async AVAsset metadata)
2. Synchronous FLAC byte scan (parseArtworkDirect)
3. Solid black #08080e background
```

## Known Issues

- **Mini player window switching crashes** — macOS `_NSWindowTransformAnimation dealloc` bug.
- **Occasional startup crash** (~20% on some macOS versions) from the same window animation bug.
- Some songs lack embedded lyrics/artwork — falls back through the tiers above.

## Development Pitfalls & Lessons Learned

### 1. Swift Concurrency — Async Metadata Race Condition

**问题:** `MetadataParser.parse()` 是 async 函数，在后台线程解析元数据后回调更新 Track 对象。但 `loadTracksFromMusicFolder()` 每次调用都会重新排序并创建新的 playlist 数组，导致 async 回调中通过 UUID 查找 Track 时找不到。

**解决:** 在创建 Task 时直接捕获 Track 对象引用：
```swift
let capturedTrack = track
metadataTasks[trackID] = Task { [weak self] in
    guard let meta = await MetadataParser.parse(from: capturedURL) else { return }
    self.updateTrackDirect(capturedTrack, with: meta)
}
```

**教训:** Swift 中 `Array` 是值类型。异步回调中不要依赖 UUID 查找，直接捕获引用。

### 2. FLAC 封面格式 — Vorbis METADATA_BLOCK_PICTURE

**问题:** FLAC 文件的封面是 Vorbis comment 格式包装，不是标准 JPEG/PNG。`AVAsset` 有时无法识别。

**解决:** 手动解析 Vorbis 头提取原始图片数据，AVAsset 失败时 fallback 到 ffmpeg。

### 3. NSImage(data:) 在 SwiftUI App 中失效

**问题:** 同样的代码在独立脚本中正常，但在 SwiftUI App 中返回 nil。

**解决:** 移除所有 `@State` 缓存，直接在 View body 中创建 NSImage。

### 4. SwiftUI `.background()` 在窗口缩放动画中的行为

**问题:** 窗口最大化动画期间 `.background()` 会向背景视图提议中间尺寸，导致封面跳动。

**解决:** 在窗口缩放前销毁封面视图，缩放完成后重建（通过 NotificationCenter）。

**教训:** `NSWindow.zoom(_:)` 是绿色按钮实际调用的方法，不是 `toggleFullScreen(_:)`。

### 5. macOS 全屏模式闪退

**问题:** 全屏退出时 `_NSExitFullScreenTransitionController` 崩溃。

**解决:** `collectionBehavior = [.fullScreenNone]` + 覆盖 `toggleFullScreen(_:)` 改为 `zoom(_:)`。

### 6. 调试 GUI App 的 NSLog 输出

**问题:** `print()` 在 GUI App 中不可见。

**解决:** 用 `NSLog()` + 直接运行二进制文件：
```bash
/tmp/.../MacMusicPlayer.app/Contents/MacOS/MacMusicPlayer 2>&1 | head -100
```

### 7. Xcode 项目设置覆盖 Info.plist

**问题:** `.pbxproj` 中的 `INFOPLIST_KEY_*` 覆盖 Info.plist 的值。

**解决:** 检查并修改 `.pbxproj` 中的对应设置。

### 8. ThemeManager — ObservableObject 驱动主题切换

**问题:** 用 `static` 属性存储主题色，切换后视图不刷新。

**解决:** 创建 `ThemeManager: ObservableObject`，用 `@Published var accent`，所有视图用 `@ObservedObject` 观察。

**教训:** SwiftUI 视图只响应 `@Published` / `@ObservedObject` 变化。`static` 属性变化不会触发重绘。

### 9. NSVisualEffectView 回到前台闪黑色

**问题:** 应用从后台回到前台时，毛玻璃效果短暂显示黑色。

**解决:** 设置 `backgroundColor` 为深色（#08080e）+ 监听 `didBecomeActiveNotification` 强制重绘。

### 10. 控制栏自动隐藏与播放列表冲突

**问题:** 播放列表打开时滚动选歌，控制栏会自动隐藏。

**解决:** 移除播放列表状态检查，让控制栏始终可以自动隐藏。

### 11. 迷你窗口恢复主窗口状态丢失

**问题:** 从迷你窗口恢复主窗口时，播放列表状态和窗口大小丢失。

**解决:** 使用 `@AppStorage` 持久化播放列表状态，恢复时检查并应用正确的窗口大小。

### 12. 播放列表窗口扩展

**问题:** 播放列表在窗口内显示，与控制栏重叠。

**解决:** 点击播放列表按钮时扩展窗口宽度（900 → 1180），播放列表作为右侧面板显示。

### 13. 进度条滑块定位

**问题:** 进度条滑块与进度条不居中，拖拽时位置偏移。

**解决:** 使用 `.position()` 精确定位，滑块和进度条完全居中对齐。

### 14. LRC 时间戳解析 — 百分秒 vs 毫秒

**问题:** LRC 文件格式 `[mm:ss.xx]` 中 `xx` 是百分秒（00-99），但解析器错误地当作毫秒处理（除以 1000），导致所有歌词时间缩小 10 倍。

**解决:** 根据小数位数自动判断：
```swift
let divisor: Double = ms.count == 2 ? 100.0 : 1000.0
let time = minutes * 60 + seconds + fraction / divisor
```

**教训:** LRC 标准中 2 位数是百分秒，3 位数是毫秒。解析器必须区分处理。

### 15. DFF/DSD 文件支持

**问题:** macOS 的 AVQueuePlayer 不支持 DSD 格式解码，无法直接播放 DFF/DSF 文件。

**解决:** 检测到 DSD 文件时，通过 ffmpeg 实时转码为 WAV（PCM 16-bit）再播放。同时用 ffmpeg 提取 DSD 文件的元数据（标题/歌手/专辑/歌词/封面）。

**临时文件管理:** 转码产生的临时 WAV 文件在切歌或清空队列时自动清理。

## Design Reference

`lx-music-design.html` — interactive HTML mockup showing the full layout. `lx-music-plan.md` has the original transformation plan.
