# Changelog

All notable changes to FlutterIPTV will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.6.6] - 2026-09-10

### Fixed
- **体验闭环与错误文案（P2-B1）**：
  - **EPG 失败原因上屏**：播放器内 EPG 面板原本只显示"暂无节目单"，无法区分"空数据"与"加载失败"。现加载失败时显示红色错误条 + 具体原因（来自 P1-9 的 `EpgProvider.error`）+ 重试按钮；`EpgProvider` 新增 `retry()` 复用上次 URL 重新加载。/ **EPG error surfaced**: the player EPG panel now shows a red error banner with the specific reason and a retry button instead of a generic "no programs" message.
  - **设置页 EPG 状态绑定真实错误**：失败时提示追加 `EpgProvider.error` 的具体原因。/ **Settings EPG status** now appends the real error reason on failure.
  - **播放列表导入错误文案**：解析器抛出的 `errorTimeout`/`errorNetwork`/404/403 等内部键串改为经 `friendlyPlaylistError()` 映射为友好文案（新增 `lib/core/utils/error_messages.dart`），导入对话框与刷新 SnackBar 均使用。/ **Playlist import error text**: raw error keys are now mapped to friendly, localized messages via `error_messages.dart`.

### Changed
- **性能小优化（P2-B2）**：
  - **`getAvailableDates` 缓存**：原本每次面板重建都 O(n) 遍历全部节目求日历日窗口；现按（频道 key）缓存，随 `_dataVersion` 失效。/ **getAvailableDates cache**: cached per channel, invalidated by data version.
  - **台标滚动暂停真正生效**：`ChannelProvider.pauseLogoLoading/resumeLogoLoading` 此前是空操作（两个 TODO），现委托全局台标状态管理器在滚动时挂起待加载队列，降低快速滚动卡顿。**Windows 桌面端已禁用该暂停逻辑**（桌面滚动事件特性不同，开启会导致台标延迟/卡住不加载）。/ **Logo scroll pause** now actually defers logo loads while scrolling; **disabled on Windows** where it would stall logo loading.
  - **解析 isolate 阈值下调**：M3U/TXT 解析的 isolate 阈值由 500KB 降至 100KB，减少低端设备主线程解析掉帧。/ **Parser isolate threshold** lowered from 500KB to 100KB.

### Fixed
- **健壮性与边缘（P2-B3）**：
  - **静默 catch 升级**：审计热路径后，将 DLNA 启用/禁用状态持久化失败的日志由 debug 升级为 warning（否则下次启动不自动开启 DLNA 且无感知）。/ **Silent catches**: DLNA persistence failures now logged at warning level.
  - **手动"修复数据库"入口**：`DatabaseHelper` 新增 `repairDatabase()`，设置页"备份与恢复"区块新增"修复数据库"按钮，极端脏数据时可手动清理孤儿行（启动自动清理已降级为一次性）。/ **Manual DB repair**: added a "Repair database" button that triggers orphan cleanup on demand.
  - **多屏释放竞态防护**：`_disposeScreenPlayer` 异步释放后仅在屏幕仍指向同一 player 时才置空，避免"暂停→快速恢复"时新播放器被旧异步释放误清空。/ **Multi-screen dispose race**: async dispose no longer clobbers a newer player.
  - **VideoController 释放**：确认 `ScreenPlayerState.dispose()` 已置空 `videoController` 引用（media_kit 的 `VideoController` 无 `dispose()`，置空交由 GC 为正确做法）。/ **VideoController**: reference is already nulled on dispose (media_kit has no `dispose()` for it).

## [1.6.5] - 2026-09-10

### Fixed
- **资源泄漏 / 稳定性（P1）**：
  - **设置监听器泄漏**：`main.dart` 中 `addListener` 用了匿名闭包，而 `removeListener` 指向从未注册过的具名方法，导致 `SettingsProvider` 单例上监听器随使用累积。现已统一使用具名方法，配对移除。/ **Settings listener leak**: the anonymous `addListener` closure could never be removed by the `removeListener` call (which referenced a different named method), leaking listeners on the settings singleton; now both use the same named method.
  - **多屏退出原生资源泄漏**：`MultiScreenProvider.dispose()` 同步调用异步的 `screen.dispose()`、`pauseAllScreens()` 同步 `dispose()` 播放器，退出时 4 个 mpv 实例的原生资源未被释放。现已改为异步触发释放并兜底捕获异常。/ **Multi-screen native leak**: dispose paths called async player teardown without awaiting; now fire the async release and catch errors so mpv instances are released on exit.
  - **数据库迁移异常被吞**：迁移中 `catch` 仅 `log.d`，真实失败（如列类型冲突）会让后续查询静默"no such column"全线崩溃。新增幂等列检查辅助，并以 `log.e` 暴露真实错误；同时补充 `onDowngrade`（版本回退时删除重建）。/ **DB migration errors swallowed**: migration failures were only logged at debug level; now use an idempotent column check and `log.e`, plus an `onDowngrade` handler that recreates the schema.
  - **EPG 解析错误静默返回 null**：畸形/空 EPG 仅让用户看到笼统"加载失败"。解析失败现携带具体原因，并经 `EpgService.lastError` 透传到 UI。/ **EPG parse errors silenced**: a malformed EPG returned null silently; the specific reason is now surfaced via `EpgService.lastError`.
  - **播放列表 URL 导入重复下载**：整份列表被下载两次（一次备份、一次解析器内部再下），且无超时/取消。已重构解析器抽出 `parseFromContent`，导入改为只下载一次复用；下载加上连接/接收超时与 `CancelToken`（可经 `cancelImport()` 中止）。/ **Playlist double-download**: the full list was fetched twice (backup + parser-internal re-fetch) with no timeout/cancel; the parser now accepts pre-fetched content and imports download once, with connect/receive timeouts and a `CancelToken`.
  - **EPG 面板宽度每帧重算**：`_computePanelWidth` 在每次 `build` 对当日全部节目跑 `TextPainter.layout()`。现按（频道+选中日+EPG 版本）缓存结果，仅数据变化时才重算。/ **EPG panel width recomputed per frame**: `_computePanelWidth` ran a `TextPainter` for every program on each build; now cached by (channel + selected date + EPG version).
  - **启动孤儿行全表扫描**：每次冷启动都跑 `NOT IN` 扫描清理孤儿数据。P0 增量刷新后孤儿基本不再产生，已用一次性标志位降级，避免无谓的全表扫描。/ **Startup orphan scan**: the `NOT IN` orphan purge ran on every cold start; now gated behind a one-time flag since incremental refresh prevents orphans.

## [1.6.4] - 2026-09-10

### Fixed
- **刷新播放列表丢失观看历史**：刷新改为增量 upsert（按「名称 + URL」复用既有频道 id），不再整表删除重建，收藏与观看记录的外键关联不会被级联清空；只有真正下线的频道才删除。/ **Watch history lost on refresh**: playlist refresh now upserts in place by reusing existing channel ids (name + URL), so favorites and watch history are no longer cascade-deleted; only channels that really went offline are removed.
- **EPG 频道匹配失败**：查询侧的 channelId 与解析侧一致地规范化，大小写/符号不一致的频道，以及仅含 `<programme>` 而无 `<channel>` 节点的节目源，不再长久显示"暂无节目单"。/ **EPG channel matching**: channel ids are normalized on the lookup side as well, fixing channels with case/symbol mismatches and sources that only provide `<programme>` without `<channel>` nodes.
- **快速连续切台播错流**：为播放流程引入代际校验，先发请求在 302 解析 / `open()` 完成后会自我作废，不再把旧流写进播放器或把旧错误提示盖到当前频道上。/ **Fast channel switching**: added a playback-generation guard so superseded requests discard themselves after their awaits instead of opening a stale stream or overwriting current state.
- **软件解码回退后黑屏**：回退与缓冲强度变更现在会等待播放器实例重建完成后再起播，并在重建前取消全部播放器事件订阅、释放旧参数流。/ **Software fallback black screen**: fallback and buffer-strength changes now wait for the player to be rebuilt before starting playback, cancelling all player subscriptions and the video-params stream beforehand.
- **软解回退不可逆**：偶发的一次硬解失败会把播放器永久重建为 `hwdec=no`，此后整个会话都走软解（4K 卡顿、HLG 色彩发灰），只能重启应用恢复。回退现在只对当次播放生效，换频道即恢复到设置的解码模式。/ **Irreversible software fallback**: a single transient hardware-decode failure used to rebuild the player as `hwdec=no` for the rest of the session (4K stutter, washed-out HLG colors) until restart. Fallback is now scoped to the current playback and is reverted when switching channels.
- **起播丢包误触发软解回退**：由码流不完整（缺 PPS/SPS、丢 NALU）引发的错误不再触发回退——换软解对丢包无效。/ **Stream errors triggering fallback**: errors caused by an incomplete stream (missing PPS/SPS, dropped NALU) no longer trigger fallback, since software decoding cannot fix packet loss.
- **HLG 源颜色发灰**：`vo=libmpv` 下 mpv 探测不到显示器能力，`target-prim/trc=auto` 会退化成"不转换"，bt.2020 + HLG 被原样送到 SDR 显示器。现在显式下变换到 SDR。/ **Washed-out HLG colors**: under `vo=libmpv` mpv cannot detect display capabilities, so `target-prim/trc=auto` degenerates to "no conversion" and bt.2020 + HLG was passed through to SDR displays. Conversion is now explicit.

### Changed
- **EPG 查询性能**：当前节目 / 下一个节目由全量线性扫描改为二分查找 + 结果缓存（该接口在频道卡片与播放器控件的 build 路径上被逐项调用）。/ **EPG lookup performance**: current/next program lookups now use binary search plus a cache instead of a full linear scan.
- **HLG 色彩策略**：由"交给 mpv 默认处理"改为显式指定目标色彩空间（bt.709 / bt.1886 / bt.2390），软解与硬解路径表现一致。/ **HLG color policy**: no longer relies on mpv defaults; the target color space is set explicitly, so software and hardware decoding paths behave identically.

## [1.6.3] - 2026-09-08

### Added
- **频道实时快照预览**：悬停（Windows 鼠标）或聚焦（TV）频道时预览实时画面，离开/失焦自动回退为台标，可在设置中开关；需 rtp2httpd 服务端开启 `video-snapshot` 才能生效。/ **Channel live snapshot preview**: preview the live frame on hover (Windows mouse) or focus (TV), auto-fall back to the logo on leave, toggleable in Settings; requires the `video-snapshot` option enabled on the rtp2httpd server.

### Changed
- **直播起播优化**：优化直播流起播速度与缓冲策略，并收敛非关键日志噪声。/ **Live streaming optimization**: improved live-stream startup speed and buffering strategy, and reduced non-critical log noise.
- **大文件拆分重构**：将设置页、频道页、首页与播放器页拆分为独立组件，提升可维护性与可读性。/ **Modular refactor**: split the Settings, Channels, Home and Player pages into standalone components for better maintainability and readability.
- **启动性能与测试**：优化启动性能，并为 EPG 逻辑补充纯逻辑单元测试。/ **Startup performance & tests**: improved startup performance and added pure-logic unit tests for the EPG logic.
- **依赖升级**：file_picker、wakelock_plus、cached_network_image、material_ui/cupertino_ui、logger 升级至最新稳定版。/ **Dependency upgrades**: bumped file_picker, wakelock_plus, cached_network_image, material_ui/cupertino_ui and logger to the latest stable versions.

### Fixed
- **台标渲染锯齿**：logo 缩小采样时提升质量，消除边缘锯齿。/ **Logo aliasing**: higher sampling quality when scaling, eliminating edge aliasing.
- **EPG 跨天节目日期窗口**：日期窗口末尾跨天节目（如 22:00→00:00）不再导致多出一天空节目页面。/ **EPG overnight programs**: programs crossing midnight at the end of the date window no longer add an extra empty-day page.
- **EPG 自动滚动定位**：修复自动定位受窗口高度影响导致滚动不准的问题。/ **EPG auto-scroll**: fixed inaccurate scrolling caused by window height.
- **稳定性**：启动初始化失败时不再错误跳转首页、启用 SQLite 外键级联删除并清理遗留数据、修复多处监听器泄漏、为全局未捕获异常增加兜底处理、修复小窗渲染溢出、修复 README 语言切换与字体设置不一致问题。/ **Stability**: no longer incorrectly navigating to Home after init failure, enabled SQLite FK cascade + orphan-data cleanup, fixed listener leaks, added a global uncaught-exception fallback, fixed small-window render overflow, and fixed README language-switch and font-setting inconsistencies.

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
