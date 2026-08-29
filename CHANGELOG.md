# Changelog

All notable changes to FlutterIPTV will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.6.2] - 2026-08-22

### Added
- **首页/分类页字体调节**：可选节目名称与 EPG 节目单字体大小（80%~120%），不影响其他位置字体，并修复放大字体导致的底部溢出。/ **Home & Category font scaling**: configurable channel name and EPG program guide font size (80%~120%), isolated from other UI, with bottom-overflow fix at large font.
- **电子节目单（EPG）增强**：回看日期由 EPG 数据动态反推（自动适配 8+1 等源）、竖排日期列、面板宽度自适应最长节目名、自动定位当前时段并高亮（直播 + 回放高亮/回放中标识）。/ **EPG program guide enhancements**: catchup date range derived dynamically from EPG data (auto adapts to 8+1 style sources), vertical date column, panel width auto-fits the longest program name, auto-scroll & highlight of the current program (live highlight + catchup highlight with playing indicator).
- **回看（catchup）时间参数**：对齐 Kodi pvr.iptvsimple 标准与 rtp2httpd（`${utc}/${utcend}/${timestamp}/${duration}`、`${(b/e)yyyyMMddHHmmss:UTC}`、`${offset}`、`{utc:格式}` 等）。/ **Catchup time parameters**: aligned with Kodi pvr.iptvsimple and rtp2httpd (`${utc}/${utcend}/${timestamp}/${duration}`, `${(b/e)yyyyMMddHHmmss:UTC}`, `${offset}`, `{utc:format}`, etc.).
- **硬解配置增强**：自动（安全）硬解方案下可配置 `vf=d3d11vpp` 去交错参数（bob/adaptive/mocomp/off）。/ **HW-decoding config**: configurable `vf=d3d11vpp` deinterlace parameters (bob/adaptive/mocomp/off) under Auto (Safe) hardware-decode mode.

### Changed
- **UI 迁移**：迁移至独立 material_ui/cupertino_ui 包（随 Flutter 设计系统解耦）、升级 shimmer 至 4.0.0、适配 file_picker 正式版 API。/ **UI migration**: moved to standalone material_ui/cupertino_ui packages (design-system decoupling), upgraded shimmer to 4.0.0, adapted file_picker stable API.
- **EPG 面板视觉**：背景改为渐变透明，对齐播放器分类面板。/ **EPG panel visuals**: background changed to transparent gradient, aligned with the player category panel.
- **版本链接**：全部指向新仓库 KLGIT886/FlutterIPTV。/ **Version links**: all point to the new repository KLGIT886/FlutterIPTV.

### Fixed
- **EPG 规范化串扰**：4K/8K 频道（如 CCTV4K/CCTV8K/beijingstv_4k）不再与标清版本错误串扰；高清频道优先匹配自有节目单，无数据时回落到标清版本。/ **EPG normalization conflating 4K/8K channels** (CCTV4K/CCTV8K/beijingstv_4k) with SD versions; HD channels now prefer their own program list and fall back to SD when absent.
- **EPG 自动滚动失效**：修复懒加载下 ensureVisible 无法定位当前节目。/ **EPG auto-scroll broken**: fixed ensureVisible failing to locate the current program under lazy loading.

### Removed
- **Vulkan 硬解方案**：h264 Vulkan 解码初始化崩溃。/ **Vulkan hardware-decode mode**: h264 Vulkan decode init crashed.

## [1.1.30] - 2024-12-21

### Added
- **Player Category Panel**: Press LEFT key to open category/channel panel in player
- Auto-locate current playing channel when opening category panel
- Double-press BACK to exit player (prevents accidental exit)

### Changed
- Category order now preserves M3U file original order (instead of alphabetical)
- Disabled LEFT/RIGHT seek for live streams (not applicable)

### Fixed
- Fixed status indicator color not updating (LIVE/Buffering/Offline)
- Fixed category selection highlight not clearing properly

## [1.1.28] - 2024-12-21

### Added
- **Lotus Theme UI**: Pure black background with pink/purple gradient accents
- **TV Sidebar Navigation**: Auto-collapsing sidebar (expands on focus)
- **Native ExoPlayer**: Media3 ExoPlayer for Android TV 4K playback
- Glassmorphism style cards for desktop/mobile
- Channel long-press menu on TV (favorite/test)
- Default channel logo for missing thumbnails
- Recommended channels with refresh button

### Changed
- TV interface optimized: removed animations for smooth performance
- Home screen redesigned with compact header and horizontal category chips
- Channel rows show max 7 items with "More" button
- Favorites section moved to bottom (only shows if has favorites)

### Fixed
- Fixed recommended channels not showing on first load
- Fixed Android TV app icon not using custom icon

## [1.0.15] - 2024-12-14

### Added
- Added video resolution display in player status bar
- Added fullscreen toggle button in player controls
- Added favorite toggle button in player top bar

### Changed
- Removed limit on Home screen categories (shows all now)
- Changed Home screen "All Channels" section to show 10 random channels

## [1.0.13] - 2024-12-14

### Fixed
- Fixed URL parsing for M3U lines containing specific suffix formats (e.g. `$`)

## [1.0.12] - 2024-12-14

### Added
- Added support for local channel logos (images from local storage)
- Improved channel logo rendering support

## [1.0.11] - 2024-12-14

### Fixed
- Fixed player controls not disappearing when mouse leaves the window
- Fixed player status getting stuck on "Buffering" or "Loading" after playback starts
- Fixed issue where pause/play was required to sync player state

## [1.0.10] - 2024-12-14

### Fixed
- Fixed navigation bar disappearing on Windows (added mouse hover detection)
- Fixed issue where video audio continues playing after exiting player screen
- Improved player controls visibility logic

## [1.0.9] - 2024-12-14

### Fixed
- Fixed issue where channel list would not update after adding/importing a playlist until restart
- Improved UI responsiveness during playlist operations

## [1.0.8] - 2024-12-14

### Fixed
- Fixed database migration error (`no such column: channel_count`) for existing users
- Updated database schema version to 2

## [1.0.7] - 2024-12-14

### Fixed
- Fixed "Database not initialized" error on Windows by initializing FFI engine early in `main.dart`
- Implemented "From File" playlist import functionality with performance optimization

## [1.0.6] - 2024-12-14

### Fixed
- Upgraded Gradle Wrapper to 8.0 to fix Android build failure

## [1.0.5] - 2024-12-14

### Fixed
- Fixed GitHub Actions ZIP creation failure by adding `-Force` parameter

## [1.0.4] - 2024-12-14

### Fixed
- Fixed GitHub Actions build failure by aligning Flutter version (3.16.9) with local environment
- Resolved `win32` compatibility issues

## [1.0.3] - 2024-12-14

### Fixed
- Fixed critical startup crash (LateInitializationError)
- Fixed "app not responding" during M3U import using batch database insert
- Fixed video playback continuing after exiting player screen (audio playing in background)
- Fixed Windows CI build failure due to package name casing
- Optimized cold start time significantly by moving heavy initialization to Splash Screen
- Switched to Dio for more robust playlist downloading

## [1.0.2] - 2024-12-13

### Fixed
- Fixed Android build configuration (SDK version and Gradle settings)
- Fixed Windows CI build by auto-generating platform files
- Updated compileSdk to 34 to support latest dependencies

## [1.0.1] - 2024-12-13

### Fixed
- Fixed multiple import path errors in providers and screens
- Fixed `TVFocusable` widget const constructor issues
- Removed unused `google_fonts` dependency
- Fixed `shortcuts` map type issue in `main.dart`

## [1.0.0] - 2024-12-13

### Added
- Initial release of FlutterIPTV
- **Multi-Platform Support**
  - Windows (PC) with keyboard/mouse navigation
  - Android Mobile with touch-optimized interface
  - Android TV with full D-Pad/Remote navigation
- **Video Player**
  - High-quality playback using media_kit (libmpv)
  - Support for HLS, DASH, RTMP/RTSP streams
  - Hardware-accelerated decoding
  - Playback speed control (0.5x - 2.0x)
  - Volume control with mute toggle
- **Playlist Management**
  - Import M3U/M3U8 playlists from URL
  - Import local playlist files
  - Automatic playlist refresh
  - Multiple playlist support
- **Channel Features**
  - Automatic grouping by categories
  - Channel search by name or group
  - Favorites with drag-and-drop reordering
  - Watch history tracking
- **Settings**
  - Playback buffer configuration
  - Auto-play preferences
  - Last channel memory
  - Parental control with PIN
- **UI/UX**
  - Beautiful dark theme optimized for TV
  - Smooth animations and transitions
  - Focus-based navigation for TV remotes
  - Responsive design for all screen sizes

### Technical
- Flutter 3.x compatible
- Provider state management
- SQLite local database
- MediaKit video player integration
- Platform channel for Android TV detection

---

## [Unreleased]

### Planned Features
- EPG (Electronic Program Guide) support
- Channel logos caching
- Multiple audio track selection
- Subtitle support
- Picture-in-Picture mode (Android)
- Chromecast support
- Recording functionality
