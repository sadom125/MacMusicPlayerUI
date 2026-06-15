# LX Music macOS Client

<div align="center">
  <br />
  <p><strong>沉浸式歌词播放器 — Dark Immersion 设计</strong></p>
  <p>
    <img src="https://img.shields.io/badge/macOS-12.0%2B-blue" alt="macOS 12.0+" />
    <img src="https://img.shields.io/badge/Swift-6.0-orange" alt="Swift 6.0" />
    <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License" />
  </p>
</div>

---

基于 [samzong/MacMusicPlayer](https://github.com/samzong/MacMusicPlayer) 增量改造的 macOS 原生音乐播放器，专注于**沉浸式歌词体验**。

## 设计风格

**Dark Immersion** — 纯黑底 `#08080e` + 蓝 accent `#60b0ff` + 紫辅助 `#b388ff`

- 🎵 封面作为全幅背景，底部渐变淡出 + 环境光晕呼吸动画
- 📝 居中 LRC 滚动歌词，active 行高亮 + `past/near/active` 三层透明度
- 🖼️ 支持 FLAC 内嵌封面/歌词的同步字节扫描（无需等待异步解析）
- 🎛️ 控制栏 3 秒无操作自动淡出隐藏，鼠标经过恢复

## 功能

- 🎧 本地音乐播放（mp3/m4a/wav/flac/aac/ogg/aiff）
- 📝 **LRC 歌词支持**：外置 `.lrc` 文件 → FLAC 内嵌 LYRICS 标签 → 字节扫描兜底
- 🖼️ **封面显示**：ID3/Vorbis 封面 → FLAC 字节扫描 JPEG/PNG → 纯黑背景
- 🔄 播放模式：列表循环 / 单曲循环 / 随机播放
- 🎮 媒体键控制 + 菜单栏快捷操作
- 📚 多音乐库支持
- 📥 YouTube 下载（需 yt-dlp + ffmpeg）
- 🌙 阻止休眠

## 最低要求

- macOS 12.0 (Monterey) 或更高

## 构建

```bash
git clone https://github.com/你的用户名/MacMusicPlayer.git
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
3. 纯黑 #08080e 背景
```

## 沉浸式控制栏

- 播放中 3 秒无操作 → 控制栏向下淡出隐藏
- 鼠标移动 → 立即恢复显示
- 暂停时始终可见

## 技术栈

| 组件 | 技术 |
|------|------|
| 播放引擎 | AVQueuePlayer |
| 元数据 | AVAsset.metadata + 同步字节扫描 |
| UI 框架 | SwiftUI + AppKit (NSHostingView) |
| 毛玻璃 | NSVisualEffectView (.hudWindow) |
| 持久化 | UserDefaults + JSON |
| 最低系统 | macOS 12.0 |

## 致谢

- [samzong/MacMusicPlayer](https://github.com/samzong/MacMusicPlayer) — 原始开源项目

## License

MIT License — 详见 [LICENSE](LICENSE) 文件。
