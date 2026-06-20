# MacMusicPlayer

<div align="center">
  <br />
  <p><strong>Glass 风格 macOS 原生音乐播放器</strong></p>
  <p>
    <img src="https://img.shields.io/badge/macOS-12.0%2B-blue" alt="macOS 12.0+" />
    <img src="https://img.shields.io/badge/Swift-6.0-orange" alt="Swift 6.0" />
    <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License" />
  </p>
</div>

---

基于 [samzong/MacMusicPlayer](https://github.com/samzong/MacMusicPlayer) 增量改造的 macOS 原生音乐播放器，采用 **Glass 毛玻璃设计语言**，支持系统主题自动跟随。

## 设计亮点

- 🪟 **整个窗口 Glass 效果** — NSVisualEffectView + ultraThinMaterial，深色/浅色模式下都呈现通透的毛玻璃质感
- 🎨 **系统主题跟随** — 自动跟随 macOS 深色/浅色模式切换，0.15 秒即时响应
- 🎵 **动态渐变背景** — 从专辑封面提取主色调，生成柔和的渐变背景
- 📝 **沉浸式歌词** — 横向布局：左侧专辑封面 + 右侧滚动歌词
- 🎛️ **悬浮控制栏** — 双行紧凑布局，居中悬浮于内容之上，glass 背景
- 📋 **浮动播放列表** — 右侧滑入的卡片式设计，全圆角，弹簧动画
- 🪟 **迷你播放器** — 圆角玻璃面板，与主窗口风格统一

## 功能

- 🎧 本地音乐播放（mp3/m4a/wav/flac/aac/ogg/aiff/dff/dsf）
- 📝 **LRC 歌词支持**：外置 `.lrc` 文件 → FLAC 内嵌 LYRICS 标签 → 字节扫描兜底
- 🖼️ **封面显示**：ID3/Vorbis 封面 → FLAC 字节扫描 JPEG/PNG → 动态渐变
- 🔄 播放模式：列表循环 / 单曲循环 / 随机播放
- 🎮 媒体键控制 + 键盘快捷键（空格播放/暂停、方向键快进快退）
- 📚 多音乐库支持
- 📥 YouTube 下载（需 yt-dlp + ffmpeg）
- 🌙 阻止休眠
- 🎨 **主题切换**：系统跟随 / 强制深色 / 强制浅色

## 截图

<img width="1238" height="794" alt="image" src="https://github.com/user-attachments/assets/745562ab-e635-4d85-9552-1c0e7aca9898" />

## 最低要求

- macOS 12.0 (Monterey) 或更高

## 下载

从 [Releases](https://github.com/sadom125/MacMusicPlayerUI/releases) 页面下载 DMG 文件，拖入 Applications 即可使用。

## 构建

```bash
git clone https://github.com/sadom125/MacMusicPlayerUI
cd MacMusicPlayer

xcodebuild -project MacMusicPlayer.xcodeproj \
  -scheme MacMusicPlayer \
  -derivedDataPath /tmp/MacMusicPlayerDerivedData \
  -destination "platform=macOS" build

open /tmp/MacMusicPlayerDerivedData/Build/Products/Debug/MacMusicPlayer.app
```

或在 Xcode 中打开 `MacMusicPlayer.xcodeproj`，⌘B 构建 → ⌘R 运行。

## 歌词加载策略（四级降级）

```
1. 外置 .lrc 文件（与音频同目录）
2. 音源内嵌 LYRICS 标签（async AVAsset）
3. 同步 FLAC 字节扫描 LYRICS（兜底，无需等待异步解析）
4. 歌名/歌手/专辑 fallback
```

## 封面加载策略（三级）

```
1. Track.albumArtData（async AVAsset）
2. 同步 FLAC 字节扫描 JPEG/PNG（兜底）
3. 动态渐变背景（ColorExtractor 提取主色调）
```

## 文件名解析

支持以下格式自动解析歌名和歌手：

```
歌名 - 歌手    →  title=歌名, artist=歌手
歌名-歌手      →  title=歌名, artist=歌手
歌名           →  title=歌名, artist=未知
```

嵌入式元数据（ID3/Vorbis）优先级高于文件名解析。

## 键盘快捷键

| 快捷键 | 功能 |
|--------|------|
| 空格 | 播放 / 暂停 |
| ← | 快退 10 秒 |
| → | 快进 10 秒 |
| ↑ | 音量增加 |
| ↓ | 音量减少 |
| ⌘← | 上一首 |
| ⌘→ | 下一首 |
| ⌘F | 搜索播放列表 |
| ⌘L | 显示/隐藏播放列表 |

## 技术栈

| 组件 | 技术 |
|------|------|
| 播放引擎 | AVQueuePlayer |
| 元数据 | AVAsset.metadata + 同步字节扫描 |
| UI 框架 | SwiftUI + AppKit (NSHostingView) |
| 毛玻璃 | NSVisualEffectView + .ultraThinMaterial |
| 主题管理 | ThemeManager (轮询 + DistributedNotification) |
| 色彩提取 | ColorExtractor (CGContext 像素采样) |
| 持久化 | UserDefaults + JSON |
| 最低系统 | macOS 12.0 |

## 致谢

- [samzong/MacMusicPlayer](https://github.com/samzong/MacMusicPlayer) — 原始开源项目

## License

MIT License — 详见 [LICENSE](LICENSE) 文件。
