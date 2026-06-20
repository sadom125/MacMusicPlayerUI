# MacMusicPlayer

macOS 原生音乐播放器，Glass 毛玻璃设计语言，SwiftUI + AppKit 混合架构。

## 项目结构

```
MacMusicPlayer/
├── AppDelegate.swift              # 应用入口 + 灵动岛管理
├── Managers/
│   ├── PlayerManager.swift        # 播放控制、播放列表管理、文件名解析
│   ├── QueuePlayerController.swift # AVQueuePlayer 封装
│   ├── PlaylistStore.swift        # 播放列表持久化
│   ├── MetadataParser.swift       # 元数据解析（AVAsset + ffmpeg）
│   ├── LrcParser.swift            # LRC 歌词解析
│   ├── ColorExtractor.swift       # 专辑封面主色调提取
│   └── WebSearchManager.swift     # 网络搜索
├── Models/
│   └── Track.swift                # Track 数据模型
├── Theme/
│   └── Theme.swift                # ThemeManager（主题切换 + 系统跟随）
├── Views/
│   ├── MainPlayerWindow.swift     # NSWindow 主窗口
│   ├── MainPlayerView.swift       # 主界面 ZStack 布局
│   ├── MiniPlayerWindow.swift     # NSPanel 迷你窗
│   ├── MiniPlayerView.swift       # 迷你窗内容
│   ├── NotchPlayerWindow.swift    # 灵动岛窗口（全屏宽度 NSPanel）
│   ├── NotchPlayerView.swift      # 灵动岛内容（NotchShape + 音乐播放器）
│   ├── HomeView.swift             # 首页（统计 + 热力图 + 最近播放）
│   ├── NowPlayingView.swift       # 播放页（黑胶唱片 + 歌词）
│   └── Components/
│       ├── CompactControlBar.swift    # 双行悬浮控制栏
│       ├── SidePlaylistPanel.swift    # 右侧播放列表 + PlaybackHistory
│       ├── ListeningHeatmap.swift     # 听歌热力图
│       ├── AlbumArtBackground.swift   # 动态渐变背景
│       ├── LyricsView.swift           # 滚动歌词
│       ├── ProgressSlider.swift       # 进度条
│       └── PlaylistPanel.swift        # 旧版播放列表（保留）
```

## 设计规范

- **Glass 效果**：窗口级 NSVisualEffectView（behindWindow）+ SwiftUI ultraThinMaterial
- **主题跟随**：ThemeManager 轮询（0.15s）+ DistributedNotification 即时响应
- **颜色规则**：深色模式 = 白色文字，浅色模式 = 黑色文字
- **动画**：弹簧动画 response:0.45 dampingFraction:0.82，窗口缩放 0.4s easeInEaseOut
- **圆角**：迷你窗 22px，控制栏 16px，播放列表卡片 18px，热力图格子 6px

## 关键实现细节

### 文件名解析
支持 `歌名 - 歌手` 或 `歌名-歌手` 格式（PlayerManager + MetadataParser 两处解析）。

### PlaybackHistory
存储最近 50 首 + 每日听歌计数（dailyPlayCounts），持久化到 UserDefaults。

### 窗口显示
打开时 alphaValue=0，等 0.15s glass 渲染后淡入，避免纯色闪烁。

### 灵动岛 (Dynamic Island)
参考 boring.notch / DynamicLakePro 架构：
- 窗口全屏宽度，覆盖屏幕顶部
- 用 `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea` 精确定位 notch
- 收缩状态：NotchShape 裁剪，左边图标 + 右边均衡器
- 展开状态：340×180 卡片，封面 + 歌曲信息 + 进度条 + 控制按钮
- 均衡器：SwiftUI Timer 驱动，红色柱子，4根
- 动画：`.spring(response: 0.42, dampingFraction: 0.8)`

### 黑胶唱片动画
NowPlayingView 使用 `TimelineView(.periodic(from: .now, by: 1/60))` 驱动旋转。

### 听歌热力图
ListeningHeatmap 显示最近 30 天数据，10 秒自动刷新 + NotificationCenter 通知。

## 构建

```bash
xcodebuild -scheme MacMusicPlayer -configuration Release build
```

DMG 打包（含 Applications 快捷方式）：
```bash
rm -rf /tmp/dmg_build && mkdir -p /tmp/dmg_build
cp -R <DerivedData>/Release/MacMusicPlayer.app /tmp/dmg_build/
ln -s /Applications /tmp/dmg_build/Applications
hdiutil create -volname "MacMusicPlayer" -srcfolder /tmp/dmg_build -ov -format UDZO ~/Downloads/MacMusicPlayer.dmg
rm -rf /tmp/dmg_build
```

## GitHub

- Remote: `https://github.com/sadom125/MacMusicPlayerUI.git`
- 当前版本：v2.0.0+（UI 全面重设计 + 灵动岛）
- 暂不推送，用户先试用
