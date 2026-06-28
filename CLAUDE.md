# MacMusicPlayer

macOS 原生音乐播放器，Glass 毛玻璃设计语言，SwiftUI + AppKit 混合架构。

## 项目结构

```
MacMusicPlayer/
├── AppDelegate.swift              # 应用入口 + 灵动岛管理
├── MacMusicPlayer.xcodeproj
├── Managers/
│   ├── PlayerManager.swift        # 播放控制、播放列表管理、文件名解析
│   ├── QueuePlayerController.swift # AVQueuePlayer 封装
│   ├── PlaylistStore.swift        # 播放列表持久化
│   ├── MetadataParser.swift       # 元数据解析（AVAsset + ffmpeg）
│   ├── MetadataWriter.swift       # 元数据写入（ffmpeg 写回 ID3/Vorbis）
│   ├── LrcParser.swift            # LRC 歌词解析
│   ├── ColorExtractor.swift       # 专辑封面主色调提取
│   └── WebSearchManager.swift     # 网络搜索
├── Models/
│   └── Track.swift                # Track 数据模型（不可变 struct）
├── Theme/
│   └── Theme.swift                # ThemeManager（主题切换 + 系统跟随）
├── Views/
│   ├── MainPlayerWindow.swift     # NSWindow 主窗口
│   ├── MainPlayerView.swift       # 主界面 ZStack 布局（3 种 viewMode）
│   ├── MiniPlayerWindow.swift     # NSPanel 迷你窗
│   ├── MiniPlayerView.swift       # 迷你窗内容
│   ├── NotchPlayerWindow.swift    # 灵动岛窗口（全屏宽度 NSPanel）
│   ├── NotchPlayerView.swift      # 灵动岛内容（NotchShape + 音乐播放器）
│   ├── HomeView.swift             # 首页（统计 + 热力图 + 最近播放）
│   ├── NowPlayingView.swift       # 播放页（黑胶唱片 + 歌词 + 音乐律动）
│   ├── TrackEditorView.swift      # 元数据编辑器（搜索 + 编辑歌曲信息/封面/歌词）
│   └── Components/
│       ├── CompactControlBar.swift    # 双行悬浮控制栏 + 律动开关
│       ├── SidePlaylistPanel.swift    # 右侧播放列表 + PlaybackHistory
│       ├── ListeningHeatmap.swift     # 听歌热力图
│       ├── AlbumArtBackground.swift   # 动态渐变背景
│       ├── LyricsView.swift           # 滚动歌词
│       ├── ProgressSlider.swift       # 进度条
│       └── PlaylistPanel.swift        # 旧版播放列表（保留）
├── Info.plist
└── CLAUDE.md
```

## 设计规范

- **Glass 效果**：窗口级 NSVisualEffectView（behindWindow）+ SwiftUI ultraThinMaterial
- **主题跟随**：ThemeManager 轮询（0.15s）+ DistributedNotification 即时响应
- **颜色规则**：深色模式 = 白色文字，浅色模式 = 黑色文字
- **动画**：弹簧动画 response:0.45 dampingFraction:0.82，窗口缩放 0.4s easeInEaseOut
- **圆角**：迷你窗 22px，控制栏 16px，播放列表卡片 18px，热力图格子 6px

## 关键实现细节

### viewMode 切换（3 种模式）
主页、播放页、编辑器三个页面共存于 ZStack，用 `.opacity()` 切换：
```swift
ZStack {
    HomeView(player: player).opacity(viewMode == "home" ? 1 : 0)
    NowPlayingView(...).opacity(viewMode == "home" ? 0 : viewMode == "nowPlaying" ? 1 : 0)
    TrackEditorView(player: player).opacity(viewMode == "editor" ? 1 : 0)
}
```
⚠️ ZStack + opacity 会让所有视图保持存活并评估 body。如果子视图 body 很重（如 TrackEditorView 的数百首歌曲列表），会影响 NowPlayingView 的动画性能。

### 文件名解析
支持 `歌名 - 歌手` 或 `歌名-歌手` 格式（PlayerManager + MetadataParser 两处解析）。

### 启动优化
`loadTracksFromMusicFolder` 的文件枚举、Track 创建、元数据 Task 创建全部在 `DispatchQueue.global(qos: .userInitiated).async` 中执行，窗口无需等待加载即可显示。加载期间显示「正在加载音乐库...」转圈提示。

### 元数据解析 Task 优先级
所有元数据解析 Task 使用 `Task(priority: .background)`，避免与 60fps UI 动画（光盘旋转、律动条）竞争 CPU。

### 黑胶唱片动画
NowPlayingView 使用 `TimelineView(.periodic(from: .now, by: 1/20))` 驱动光盘旋转。
- **20fps 降频**：从 30fps 降至 20fps，肉眼无可见差异，省 ~33% CPU
- **性能优化**：只在 `isPlaying == true` 时才创建 TimelineView，暂停时显示静态 `Image(nsImage:)`，零 CPU 开销
- **暂停角度冻结**：用 `@State pauseAngle` 在 TimelineView 的 `.onChange(of: angle)` 中记录每帧角度，暂停后显示该角度
- **恢复角度连续性**：恢复播放时将 `rotationStartTime` 前移 `pauseAngle / 360 * 8` 秒，使 TimelineView 从暂停角度继续旋转

### 3D 动画效果
多个组件使用 `rotation3DEffect` 和视差偏移增强深度感：

| 组件 | 效果 | 实现 |
|------|------|------|
| 黑胶唱片 | 3D 透视倾斜跟随鼠标 | NSTrackingArea → tiltX/tiltY (±3°), interactiveSpring |
| 唱片 grooves | 微偏移层次深度 | offset(x: CGFloat(i) * 0.5) |
| 背景封面 | 慢速视差漂移 | scaleEffect(1.04) + offset 循环 (15s easeInOut) |
| 歌词行 | 远近深度旋转 | rotation3DEffect(y: 0/2/4°, perspective: 0.2) |
| 控制栏 | 升起时 3D 翻转 | rotation3DEffect(0→8°, axis: (1,0,0), anchor: .bottom) |
| 播放列表 | 门式 3D 滑入 | rotation3DEffect(0→12°, axis: (0,1,0), anchor: .leading) |

所有 3D 动画使用 `.interactiveSpring(response:dampingFraction:)` 确保流畅跟随。

### 性能优化策略

| 优化项 | 前 | 后 | 效果 |
|--------|-----|-----|------|
| TimelineView 频率 | 30fps | 20fps | CPU 降低 ~33% |
| 时间观察者 | 250ms, 持续运行 | 1s, 暂停时跳过 | 暂停时零时间回调 |
| artwork 缓存 | [UUID: Data?] 无限增长 | NSCache countLimit 50 | 内存压力时自动清理 |
| 呼吸辉光 | .repeatForever 持续运行 | 仅在播放时循环 | 暂停时 GPU 空闲 |
| 歌词逐字计算 | 每帧无条件计算 | active 行才触发逐字逻辑 | body 重建减少 |

### 音乐律动效果
NowPlayingView 中的音乐律动：
- 位置：光盘封面下方，宽度与光盘一致（320pt）
- 18 根红橙渐变柱子，播放时跳动，暂停时回弹
- 用 DispatchSource + ObservableObject 保证动画可靠性
- 控制栏波形图标开关，支持开/关
- 光盘封面偏移：`offset(x: 20, y: -10)`

### PlaybackHistory
存储最近 50 首 + 每日听歌计数（dailyPlayCounts），持久化到 UserDefaults。

### 窗口显示
打开时 alphaValue=0，等 0.15s glass 渲染后淡入，避免纯色闪烁。

### 听歌热力图
ListeningHeatmap 显示最近 30 天数据，10 秒自动刷新 + NotificationCenter 通知。

### 灵动岛 (Dynamic Island) — 暂时隐藏
参考 boring.notch / DynamicLakePro 架构（代码保留，功能已注释）：
- 窗口全屏宽度，覆盖屏幕顶部
- 用 `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea` 精确定位 notch
- 收缩状态：NotchBarShape 裁剪，红色均衡器跳动
- 展开状态：320×155 卡片，封面 48×48 + 歌曲信息 + 进度条 + 控制按钮
- 均衡器：DispatchSource + ObservableObject 驱动，双正弦波叠加
- 展开/收起：ZStack + opacity 替代 if/else，避免视图重建
- 启用方式：取消 AppDelegate.swift 中 `setupNotchPlayer()` 的注释

### 元数据编辑器 (TrackEditorView)
- 两种状态：track picker（搜索 + 歌曲列表）+ editor form（编辑表单）
- 搜索实时过滤 `player.playlist`，支持标题/歌手/专辑搜索
- 编辑表单：标题、歌手、专辑文本字段，封面预览 + 选择/移除，歌词 TextEditor
- 保存调用 `MetadataWriter.save()` 用 ffmpeg 写回 ID3/Vorbis 标签
- 歌词支持导入 LRC 文件（NSOpenPanel + 拖拽），拖拽覆盖整个 TextEditor 区域

### MetadataWriter（ffmpeg 元数据写入）
`MetadataWriter.save()` 使用 ffmpeg 将元数据写回音频文件：
- 参数顺序必须严格：所有 `-i` 输入在前，输出选项在后
- 流映射规则：
  - 替换封面：`-map 0:a -map 1:v -c copy -disposition:v attached_pic`
  - 移除封面：`-map 0:a -c copy -vn`
  - 保持原样：`-c copy`
- 不支持 DSD 格式（DFF/DSF），跳过提示
- 返回 `SavedMetadata` 结构体，含写入后的完整值（未修改的字段回退到 `originalTrack`）

## 构建

```bash
cd MacMusicPlayer
xcodebuild -project MacMusicPlayer.xcodeproj -scheme MacMusicPlayer \
  -configuration Release -derivedDataPath /tmp/MacMusicPlayerDerivedData \
  -destination "platform=macOS" build
```

DMG 打包：
```bash
rm -f ~/Downloads/MacMusicPlayer.dmg
hdiutil create -volname "MacMusicPlayer" \
  -srcfolder /tmp/MacMusicPlayerDerivedData/Build/Products/Release/MacMusicPlayer.app \
  -ov -format UDZO ~/Downloads/MacMusicPlayer.dmg
```

## GitHub

- Remote: `https://github.com/sadom125/MacMusicPlayerUI.git`
- 当前版本：v2.0.3
- Release 包含 DMG 下载

## 踩坑记录（重要！）

### 1. NSHostingView 中的动画 Timer 不可靠 ❌

**问题：** `Timer.publish` / `Timer.scheduledTimer` / `DispatchQueue.main.asyncAfter` 在 NSHostingView 中不触发或不可靠。

**错误尝试：**
```swift
// ❌ Timer.publish 在 hosted view 中不触发
private let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

// ❌ Timer.scheduledTimer 也不可靠
timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in ... }

// ❌ DispatchQueue 递归调用会被打断
let item = DispatchWorkItem { self.tick() }
DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
```

**正确方案：** `DispatchSource.makeTimerSource` + `ObservableObject` 类
```swift
class RhythmState: ObservableObject {
    @Published var bars: [CGFloat] = [6, 6, 6, 6]
    var isPlaying = false
    private static var timerKey = "timer"

    func startTimer() {
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now(), repeating: .milliseconds(120))
        source.setEventHandler { [weak self] in
            guard let self = self, self.isPlaying else { return }
            self.bars = (0..<4).map { _ in CGFloat.random(in: 4...14) }
        }
        objc_setAssociatedObject(self, &Self.timerKey, source, .OBJC_ASSOCIATION_RETAIN)
        source.resume()
    }
}
```

### 2. onChange(of:) 在 ZStack 中不触发 ❌

**问题：** 当视图在 ZStack 中通过 opacity 切换时，`onChange(of:)` 不会触发。

**正确方案：** 把 `isPlaying` 传入 ObservableObject 类，在 timer 回调中直接检查。

### 3. NSViewRepresentable 在 hosted view 中显示禁止符号 ❌

**问题：** `NSViewRepresentable` 包装的 NSView 在 NSHostingView 中可能显示 🚫 禁止符号。

**原因：** NSHostingView 对 NSViewRepresentable 的渲染有限制。

**正确方案：** 用纯 SwiftUI + DispatchSource，不用 NSViewRepresentable。

### 4. refreshView() 会杀死所有 Timer ❌

**问题：** 每次调用 `refreshView()` 重建视图时，所有 `@State` 和 Timer 订阅都会丢失。

**错误代码：**
```swift
func refreshView() {
    hostingView.rootView = AnyView(NotchPlayerView(...)) // 视图重建，timer 死掉
}
```

**正确方案：** 保持视图存活，只更新 binding，不要重建 rootView。

### 5. matchedGeometryEffect 在不同形状间变形 ❌

**问题：** 两个不同形状（NotchShape 药丸 + 圆角矩形卡片）之间做 matchedGeometryEffect morph 会导致方形变形。

**正确方案：** 不同形状之间用 opacity 切换，不要用 matchedGeometryEffect。

### 6. scaleEffect 会拉伸圆角 ❌

**问题：** 对有圆角的视图使用 `scaleEffect(x: 1.15, y: 1.3)` 会导致圆角变形。

**正确方案：** hover 效果用 shadow/glow，不用 scaleEffect 拉伸形状。

### 7. Timer 闭包捕获初始值 ❌

**问题：** Timer 闭包捕获 `isPlaying` 的初始值，后续变化不会更新。
```swift
// ❌ isPlaying 永远是创建时的值
timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
    if isPlaying { ... } // isPlaying 是旧值
}
```

**正确方案：** 用 class（引用类型）持有状态，timer 回调中读取最新值。

### 8. NSAnimationContext 和 SwiftUI 动画冲突 ❌

**问题：** 窗口用 `NSAnimationContext` resize，内容用 `.animation(.spring(...))` 过渡，两者互相干扰导致抖动。

**正确方案：** 二选一，不要同时用两套动画系统。用 ZStack + opacity 避免 SwiftUI 过渡动画。

### 9. if/else 切换销毁/重建视图 ❌

**问题：** `if/else` 在切换时销毁旧视图、创建新视图，导致动画不连贯、状态丢失。

**正确方案：** 用 ZStack + opacity 保持两个视图都存活：
```swift
ZStack {
    collapsedView.opacity(isExpanded ? 0 : 1)
    expandedView.opacity(isExpanded ? 1 : 0)
}
```

### 10. ffmpeg 参数顺序 ❌

**问题：** `-map_metadata 0` 如果放在 `-i input.flac` 和 `-i cover.jpg` 之间，ffmpeg 会把它解释为 cover.jpg 的输入选项而非输出选项，导致失败。

**正确方案：** 所有输出选项（包括 `-map_metadata`、`-metadata`、`-map`、`-c`）必须放在所有 `-i` 标志之后：
```swift
var args = ["-y", "-i", inputPath]      // 所有输入
if let art { args += ["-i", artPath] }  // 额外输入
args += ["-map_metadata", "0"]           // 输出选项才开始
args += ["-metadata", "title=..."]
args += ["-map", "0:a", "-map", "1:v", "-c", "copy"]
args += [outputPath]                     // 输出文件
```

### 11. TextEditor 拦截拖拽事件 ❌

**问题：** SwiftUI 的 `TextEditor`（底层 NSTextView）会拦截文件拖拽事件，将文件 URL 作为文本插入。父容器的 `.onDrop` 无法接收到 TextEditor 区域的文件拖拽。

**正确方案：** 在 TextEditor 上方加一层透明 `Color.clear.onDrop()` 叠加层：
```swift
ZStack {
    TextEditor(text: $text)
    Color.clear.onDrop(of: [.fileURL], isTargeted: $isTargeted) { ... }
}
```
`Color.clear` 只需添加 `.onDrop` 即可响应拖拽，无需 `.contentShape()`，不影响 TextEditor 的文本编辑手势。

### 12. TimelineView 暂停角度跳回 0° ❌

**问题：** 用 `if isPlaying { TimelineView(...) } else { staticImage }` 切换时，暂停后光盘跳回 0°。

**正确方案：**
- 用 `@State pauseAngle` 在 TimelineView 内逐帧记录角度
- 恢复时重设 `rotationStartTime`，使旋转无缝衔接：
```swift
.onChange(of: isPlaying) { newValue in
    if newValue {
        let elapsedSec = (pauseAngle / 360.0) * 8.0  // 8s 一圈
        rotationStartTime = Date().addingTimeInterval(-elapsedSec)
    }
}
```

### 13. onContinuousHover 仅 macOS 13+ + NSTrackingArea 导致抖动 ❌❌

**问题（两次踩坑）：** 最初尝试 `onContinuousHover`（macOS 13+，项目 target 12.0 → 编译错误）。改用 `NSViewRepresentable` + `NSTrackingArea` 后，`mouseMoved` 在 ~60fps 下持续触发 tilt 值更新，导致 SwiftUI 每帧重建 `rotation3DEffect`，与内部的 TimelineView（20fps 唱片旋转）渲染冲突 → 唱片异常抖动。

**最终正确方案：** 彻底放弃鼠标跟踪，用 SwiftUI 内置的 `.repeatForever` 自动摆动：
```swift
@State private var discTiltPhaseX: Bool = false
@State private var discTiltPhaseY: Bool = false

.onAppear {
    withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
        discTiltPhaseX = true
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            discTiltPhaseY = true
        }
    }
}

// 在 vinylSection 中:
let tiltX: Double = (discTiltPhaseX ? 2.0 : -2.0)  // 映射到 ±2°
let tiltY: Double = (discTiltPhaseY ? 1.5 : -1.5)  // 映射到 ±1.5°
// 然后用 rotation3DEffect，无需 .animation() modifier
```
**原理：** `.repeatForever` 是 GPU 动画合成器驱动的，不占用 CPU 也不触发 SwiftUI body 重建。两个独立相位（5s/4s + 1.25s 偏移）产生 Lissajous 式摆动，视觉上像是真实唱片在转盘上微晃。

**教训：** 任何需要高频（>10fps）更新 @State 的方案都会导致 SwiftUI 持续重建 → 动画抖动。如果 3D 效果不需要与鼠标位置关联，优先用 `.repeatForever` 这种 GPU 级动画。

### 14. [UUID: Data?] 缓存无限增长 ❌

**问题：** `MainPlayerView` 用 `@State private var artworkFallbackCache: [UUID: Data?]` 缓存专辑封面，切换大量歌曲时无限增长，占用内存不释放。

**正确方案：** 用 `NSCache<NSString, NSData>`（线程安全、自动清理）：
```swift
private let artworkCache: NSCache<NSString, NSData> = {
    let cache = NSCache<NSString, NSData>()
    cache.countLimit = 50
    return cache
}()
```
⚠️ NSCache 的 object 必须是 class 类型（NSData），不能是 struct（Data）。用 `data as NSData` / `cached as Data` 桥接。

### 15. TimelineView 频率不是越高越好 ✅

**问题：** 最初用 `1/60` (60fps) 驱动唱片旋转，对 CPU 造成不必要的压力。旋转动画的平滑度在 20fps 以上人眼几乎无法分辨。

**正确方案：** 使用 `1/20` (20fps) 结合 `interpolation(.high)` 和 `TimelineView` 的条件创建（仅播放时）：
```swift
if isPlaying {
    TimelineView(.periodic(from: .now, by: 1.0 / 20.0)) { context in ... }
}
```

### 16. Task(priority: .background) 元数据加载极慢 ❌

**问题：** `PlayerManager.loadTracksFromMusicFolder()` 使用 `Task(priority: .background)` 创建元数据解析任务。.background 是最低优先级，系统将 CPU 时间片几乎全部分给前台任务。300 首歌曲的库，最后几十首的元数据需要 30+ 秒才能解析完。用户切到那首歌时封面/歌手还是 placeholder。

**正确方案：** 提升到 `.utility`（仍然低于用户交互优先级，但不会被完全饿死）：
```swift
self.metadataTasks[track.id] = Task(priority: .utility) { ... }
```
同时加入"当前歌曲优先解析"机制：
```swift
// 前 15 首使用同步 IO 预解析（封面、歌词立即可见）
let eagerBatchSize = min(15, newPlaylist.count)
for i in 0..<eagerBatchSize { /* parseSync + parseArtworkDirect */ }

// 用户点击播放时立即高优解析当前曲目
func playTrack(at index: Int) {
    // ... 播放逻辑 ...
    ensureMetadataForCurrentTrack()  // .userInitiated 队列, 绕过 async 排队
}
```

### 17. ZStack + opacity 导致隐藏视图持续评估 body ❌

**问题：** `MainPlayerView` 用 ZStack + opacity 保持 3 个页面（HomePage/NowPlaying/Editor）共存。所有子 View 都接收 `@ObservedObject var player: PlayerManager`。当 `player.currentTime` 每秒变化时，所有 3 个子 View 的 body 都会评估（即使 opacity=0 不可见）。`TrackEditorView` 中有数百首歌曲的列表，body 评估开销很大。

**正确方案：** 组合使用：
1. **EquatableView** — 让 ForEach 中的行只在数据变化时才重绘：
```swift
struct TrackRow: View, Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.track.id == rhs.track.id && lhs.isActive == rhs.isActive
    }
}
// 在 ForEach 中使用 .equatable()
TrackRow(...).equatable()
```
2. **当前歌曲即时解析** — 不在 ZStack 层面优化（会破坏视图状态），而是让隐藏视图的 body 评估尽可能轻量。
3. **MetadataParser.parseSync()** — 仅同步 IO（无 AVAsset async），确保播放时封面秒现。

⚠️ 不要用 `if viewMode == "editor" { TrackEditorView() }` 替代 opacity — 这会销毁/重建视图，丢失搜索状态、编辑内容。ZStack + opacity 虽然 body 评估浪费，但状态保持是正确的。优先用 EquatableView 优化子视图内部。

### 18. 打包前必须杀旧进程 ✅

每次重新打包 DMG 或构建新版本前，必须先 `pkill` 旧进程再启动新版本，否则运行的是旧代码。
