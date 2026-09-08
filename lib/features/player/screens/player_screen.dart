import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../../../core/i18n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/platform/native_player_channel.dart';
import '../../../core/platform/windows_pip_channel.dart';
import '../../../core/platform/windows_fullscreen_native.dart';
import '../../../core/models/channel.dart';
import '../providers/player_provider.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../channels/providers/channel_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../settings/providers/dlna_provider.dart';
import '../../multi_screen/providers/multi_screen_provider.dart';
import '../../multi_screen/widgets/multi_screen_player.dart';
import '../../../core/services/service_locator.dart';
import '../widgets/mini_controls_overlay.dart';
import '../widgets/channel_panel.dart';
import '../widgets/gesture_overlay.dart';
import '../widgets/player_top_bar.dart';
import '../widgets/player_bottom_controls.dart';
import '../widgets/player_info_overlay.dart';
import '../widgets/interactive_epg_widget.dart';
import '../../../core/services/epg_service.dart';

class PlayerScreen extends StatefulWidget {
  final String channelUrl;
  final String channelName;
  final String? channelLogo;
  final bool isMultiScreen; // 是否强制进入分屏模式

  const PlayerScreen({
    super.key,
    required this.channelUrl,
    required this.channelName,
    this.channelLogo,
    this.isMultiScreen = false,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  Timer? _hideControlsTimer;
  Timer? _dlnaSyncTimer; // DLNA 状态同步定时器（Android TV 原生播放器用）
  Timer? _wakelockTimer; // 定时刷新wakelock（手机端用）
  bool _showControls = true;
  final FocusNode _playerFocusNode = FocusNode();
  bool _usingNativePlayer = false;
  bool _showCategoryPanel = false;
  String? _selectedCategory;
  final ScrollController _categoryScrollController = ScrollController();
  final ScrollController _channelScrollController = ScrollController();

  // 保存 provider 引用，用于 dispose 时释放资源
  PlayerProvider? _playerProvider;
  MultiScreenProvider? _multiScreenProvider;
  SettingsProvider? _settingsProvider;

  // 本地分屏模式状态（不影响设置）
  bool _localMultiScreenMode = false;

  // 保存分屏模式状态，用于 dispose 时判断
  bool _wasMultiScreenMode = false;

  // 标记是否已经保存了分屏状态（避免重复保存）
  bool _multiScreenStateSaved = false;

  // 手势控制相关变量
  double _gestureStartY = 0;
  double _initialVolume = 0;
  double _initialBrightness = 0;
  bool _showGestureIndicator = false;
  double _gestureValue = 0;

  // 本地 loading 状态，用于强制刷新
  bool _isLoading = true;

  // 错误已显示标记，防止重复显示
  bool _errorShown = false;
  Timer? _errorHideTimer; // 错误提示自动隐藏定时器

  // 提前保存 ScaffoldMessengerState 引用，供 dispose 中安全清除 SnackBar。
  // dispose() 阶段 element 已从树中移除，此时调用 ScaffoldMessenger.of(context)
  // 会触发 "Looking up a deactivated widget's ancestor is unsafe" 错误。
  ScaffoldMessengerState? _scaffoldMessenger;

  // Windows 全屏状态
  bool _isFullScreen = false;
  DateTime? _lastFullScreenToggle; // 记录上次切换时间
  bool _mouseOver = false;

  // EPG / Catchup State
  bool _showEpgPanel = false;
  Channel? _originalChannel; // Original live channel when playing catchup
  EpgProgram? _currentCatchupProgram; // Currently playing catchup program

  // 当前屏幕方向状态 (用于手机端横竖屏切换按钮)
  DeviceOrientation? _currentOrientation;

  // 检查是否处于分屏模式（使用本地状态）
  bool _isMultiScreenMode() {
    return _localMultiScreenMode && PlatformDetector.isDesktop;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 保持屏幕常亮
    _enableWakelock();
    // 延迟到 didChangeDependencies 之后再检查播放器
    // 因为需要先初始化 _localMultiScreenMode
  }

  Future<void> _enableWakelock() async {
    // 手机端使用原生方法确保屏幕常亮
    if (PlatformDetector.isMobile) {
      try {
        await PlatformDetector.setKeepScreenOn(true);
      } catch (e) {
        ServiceLocator.log.d('PlayerScreen: Failed to set keep screen on: $e');
      }
    } else {
      // 其他平台使用wakelock_plus
      try {
        // 添加短暂的延迟，确保 Flutter 引擎完全初始化
        await Future.delayed(const Duration(milliseconds: 100));
        await WakelockPlus.enable();
        final enabled = await WakelockPlus.enabled;
        ServiceLocator.log.d('PlayerScreen: WakelockPlus enabled: $enabled');
      } catch (e) {
        ServiceLocator.log.d('PlayerScreen: Failed to enable wakelock: $e');
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 保存 provider 引用并添加监听
    if (_playerProvider == null) {
      _playerProvider = context.read<PlayerProvider>();
      _playerProvider!.addListener(_onProviderUpdate);
      _isLoading = _playerProvider!.isLoading;

      // 提前保存 ScaffoldMessengerState，供 dispose 中安全清除 SnackBar
      _scaffoldMessenger = ScaffoldMessenger.maybeOf(context);

      // 保存 settings 和 multi-screen provider 引用（用于 dispose 时保存状态）
      _settingsProvider = context.read<SettingsProvider>();
      _multiScreenProvider = context.read<MultiScreenProvider>();

      // 初始化当前屏幕方向 (手机端)
      if (PlatformDetector.isMobile) {
        _currentOrientation =
            MediaQuery.of(context).orientation == Orientation.portrait
                ? DeviceOrientation.portraitUp
                : DeviceOrientation.landscapeLeft;
      }

      // 检查是否是 DLNA 投屏模式
      bool isDlnaMode = false;
      try {
        final dlnaProvider = context.read<DlnaProvider>();
        isDlnaMode = dlnaProvider.isActiveSession;
      } catch (_) {}

      // 初始化本地分屏模式状态（根据设置或传入参数）
      // 如果传入的 isMultiScreen=true，强制进入分屏模式
      // DLNA 投屏模式下不进入分屏
      _localMultiScreenMode = !isDlnaMode &&
          (widget.isMultiScreen || _settingsProvider!.enableMultiScreen) &&
          PlatformDetector.isDesktop;

      // 如果是分屏模式且分屏没有正在播放的频道，设置音量增强到分屏provider
      // 如果分屏已经有频道在播放（从主页继续播放进入），不要覆盖音量设置
      if (_localMultiScreenMode && !_multiScreenProvider!.hasAnyChannel) {
        _multiScreenProvider!.setVolumeSettings(
            _playerProvider!.volume, _settingsProvider!.volumeBoost);
      }

      // 现在可以安全地检查和启动播放器了（延迟到构建完成后，避免 setState during build）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkAndLaunchPlayer();
        }
      });
    }
    // 保存分屏模式状态
    _wasMultiScreenMode = _isMultiScreenMode();
  }

  void _onProviderUpdate() {
    if (!mounted) return;
    final provider = _playerProvider;
    if (provider == null) return;

    final newLoading = provider.isLoading;
    if (_isLoading != newLoading) {
      setState(() {
        _isLoading = newLoading;
      });
    }

    // 检查错误状态
    if (provider.hasError && !_errorShown) {
      _checkAndShowError();
    }

    // 只有 DLNA 投屏会话时才同步播放状态
    try {
      final dlnaProvider = context.read<DlnaProvider>();
      if (dlnaProvider.isActiveSession) {
        dlnaProvider.syncPlayerState(
          isPlaying: provider.isPlaying,
          isPaused: provider.state == PlayerState.paused,
          position: provider.position,
          duration: provider.duration,
        );
      }
    } catch (e) {
      // DLNA provider 可能不可用，忽略错误
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    ServiceLocator.log.d('PlayerScreen: AppLifecycleState changed to $state');
  }

  Future<void> _checkAndLaunchPlayer() async {
    // 分屏模式下不启动PlayerProvider播放，由MultiScreenProvider处理
    if (_isMultiScreenMode()) {
      // 分屏模式：隐藏系统UI，但不启动PlayerProvider
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      return;
    }

    // Check if we should use native player on Android TV
    if (PlatformDetector.isTV && PlatformDetector.isAndroid) {
      final nativeAvailable = await NativePlayerChannel.isAvailable();
      ServiceLocator.log
          .d('PlayerScreen: Native player available: $nativeAvailable');
      if (nativeAvailable && mounted) {
        _usingNativePlayer = true;

        // 检查是否是 DLNA 投屏模式
        bool isDlnaMode = false;
        try {
          final dlnaProvider = context.read<DlnaProvider>();
          isDlnaMode = dlnaProvider.isActiveSession;
          ServiceLocator.log
              .d('PlayerScreen: DLNA isActiveSession=$isDlnaMode');
        } catch (e) {
          ServiceLocator.log.d('PlayerScreen: Failed to get DlnaProvider: $e');
        }

        // 获取频道列表
        final channelProvider = context.read<ChannelProvider>();
        // 使用全部频道而不是分页显示的频道
        final channels = channelProvider.allChannels;

        // 设置 providers 用于收藏功能和状态保存
        final favoritesProvider = context.read<FavoritesProvider>();
        final settingsProvider = context.read<SettingsProvider>();
        NativePlayerChannel.setProviders(
            favoritesProvider, channelProvider, settingsProvider);

        // DLNA 模式下不使用频道列表，直接播放传入的 URL
        List<String> urls;
        List<String> names;
        List<String> groups;
        List<List<String>> sources;
        List<String> logos;
        List<String> epgIds;
        List<bool> isSeekableList;
        int currentIndex = 0;

        if (isDlnaMode) {
          // DLNA 模式：只播放传入的URL，不提供频道切换功能
          urls = [widget.channelUrl];
          names = [widget.channelName];
          groups = ['DLNA'];
          sources = [
            [widget.channelUrl]
          ];
          logos = [''];
          epgIds = [''];
          isSeekableList = [true]; // DLNA 投屏默认可拖动
          currentIndex = 0;
        } else {
          // 正常模式：使用频道列表
          // Find current channel index
          for (int i = 0; i < channels.length; i++) {
            if (channels[i].url == widget.channelUrl) {
              currentIndex = i;
              break;
            }
          }
          urls = channels.map((c) => c.url).toList();
          names = channels.map((c) => c.name).toList();
          groups = channels.map((c) => c.groupName ?? '').toList();
          sources = channels.map((c) => c.sources).toList();
          logos = channels.map((c) => c.logoUrl ?? '').toList();
          epgIds = channels.map((c) => c.epgId ?? '').toList();
          isSeekableList = channels.map((c) => c.isSeekable).toList();
        }

        ServiceLocator.log.d(
            'PlayerScreen: Launching native player for ${widget.channelName} (isDlna=$isDlnaMode, index $currentIndex of ${urls.length})');

        // TV端原生播放器也需要记录频道遍历
        if (!isDlnaMode &&
            currentIndex >= 0 &&
            currentIndex < channels.length) {
          final channel = channels[currentIndex];
          if (channel.id != null) {
            await ServiceLocator.watchHistory
                .addWatchHistory(channel.id!, channel.playlistId);
            ServiceLocator.log.d(
                'PlayerScreen: Recorded watch history for channel ${channel.name}');
          }
        }

        // 获取缓冲强度设置和显示设置
        final bufferStrength = settingsProvider.bufferStrength;
        final showFps = settingsProvider.showFps;
        final showClock = settingsProvider.showClock;
        final showNetworkSpeed = settingsProvider.showNetworkSpeed;
        final showVideoInfo = settingsProvider.showVideoInfo;
        final userAgent = settingsProvider.userAgent;

        // Launch native player with channel list and callback for when it closes
        final launched = await NativePlayerChannel.launchPlayer(
          url: widget.channelUrl,
          name: widget.channelName,
          index: currentIndex,
          urls: urls,
          names: names,
          groups: groups,
          sources: sources,
          logos: logos,
          epgIds: epgIds,
          isSeekable: isSeekableList,
          isDlnaMode: isDlnaMode,
          bufferStrength: bufferStrength,
          showFps: showFps,
          showClock: showClock,
          showNetworkSpeed: showNetworkSpeed,
          showVideoInfo: showVideoInfo,
          progressBarMode: settingsProvider.progressBarMode, // 传递进度条显示模式
          seekStepSeconds: settingsProvider.seekStepSeconds, // 传递快进/快退跨度
          showChannelName:
              settingsProvider.showMultiScreenChannelName, // 传递多屏频道名称显示设置
          userAgent: userAgent, // 传递 User-Agent
          showUserAgent: settingsProvider.showUserAgent, // 传递是否显示User-Agent
          onClosed: () {
            ServiceLocator.log.d('PlayerScreen: Native player closed callback');
            // 停止 DLNA 同步定时器
            _dlnaSyncTimer?.cancel();
            _dlnaSyncTimer = null;

            // 通知 DLNA 播放已经停止（如果是 DLNA 投屏的话）
            try {
              final dlnaProvider = context.read<DlnaProvider>();
              if (dlnaProvider.isActiveSession) {
                dlnaProvider.notifyPlaybackStopped();
              }
            } catch (e) {
              // 忽略错误
            }

            if (mounted) {
              // 杩斿洖棣栭〉
              Navigator.of(context).maybePop();
            }
          },
        );

        if (launched && mounted) {
          // Don't pop - wait for native player to close via callback
          // The native player is now a Fragment overlay, not a separate Activity

          // 如果是 DLNA 投屏，启动状态同步定时器
          _startDlnaSyncForNativePlayer();
          return;
        } else if (!launched && mounted) {
          // Native player failed to launch, fall back to Flutter player
          _usingNativePlayer = false;
          _initFlutterPlayer();
        }
        return;
      }
    }

    // Fallback to Flutter player
    if (mounted) {
      _usingNativePlayer = false;
      _initFlutterPlayer();
    }
  }

  void _initFlutterPlayer() {
    _startPlayback();
    _startHideControlsTimer();

    // Hide system UI for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // 手机端定期刷新 wakelock，防止某些设备上 wakelock 失效
    if (PlatformDetector.isMobile) {
      _wakelockTimer?.cancel();
      _wakelockTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
        if (mounted) {
          await _enableWakelock();
        }
      });
    }

    // 不再使用持续监听，改为一次错误检查
  }

  /// 为 Android TV 原生播放器启用 DLNA 状态同步
  void _startDlnaSyncForNativePlayer() {
    try {
      final dlnaProvider = context.read<DlnaProvider>();
      // 注意：不检查 isActiveSession，因为在 TV 端接收 DLNA 投屏时，
      // 这个方法可能在 isActiveSession 设置之前就被调用了
      // 只要 DLNA 服务在运行，就启动同步定时器
      if (!dlnaProvider.isRunning) {
        ServiceLocator.log
            .d('PlayerScreen: DLNA service not running, skip sync timer');
        return;
      }

      ServiceLocator.log
          .d('PlayerScreen: Starting DLNA sync timer for native player');

      // 每秒同步一次播放状态
      _dlnaSyncTimer?.cancel();
      _dlnaSyncTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        if (!mounted) {
          _dlnaSyncTimer?.cancel();
          return;
        }

        try {
          final state = await NativePlayerChannel.getPlaybackState();
          ServiceLocator.log.d('PlayerScreen: DLNA sync - state=$state');
          if (state != null) {
            final isPlaying = state['isPlaying'] as bool? ?? false;
            final position =
                Duration(milliseconds: (state['position'] as int?) ?? 0);
            final duration =
                Duration(milliseconds: (state['duration'] as int?) ?? 0);
            final stateStr = state['state'] as String? ?? 'unknown';

            dlnaProvider.syncPlayerState(
              isPlaying: isPlaying,
              isPaused: stateStr == 'paused',
              position: position,
              duration: duration,
            );
          }
        } catch (e) {
          ServiceLocator.log.d('PlayerScreen: DLNA sync error - $e');
        }
      });
    } catch (e) {
      ServiceLocator.log.d('PlayerScreen: Failed to start DLNA sync - $e');
    }
  }

  void _checkAndShowError() {
    if (!mounted || _errorShown) return;

    final provider = context.read<PlayerProvider>();
    if (provider.hasError && provider.error != null) {
      final errorMessage = provider.error!;
      _errorShown = true;
      provider.clearError();

      // 先取消之前的定时器
      _errorHideTimer?.cancel();

      // 清除之前的 SnackBar
      try {
        ScaffoldMessenger.of(context).clearSnackBars();
      } catch (e) {
        ServiceLocator.log.d('PlayerScreen: Error clearing SnackBars: $e');
        return;
      }

      final scaffoldMessenger = ScaffoldMessenger.of(context);

      final snackBar = SnackBar(
        content: Text(
            '${AppStrings.of(context)?.playbackError ?? "Error"}: $errorMessage'),
        backgroundColor: AppTheme.errorColor,
        duration: const Duration(days: 365), // 设置很长的时间，手动控制易隐藏
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: AppStrings.of(context)?.retry ?? 'Retry',
          textColor: Colors.white,
          onPressed: () {
            _errorHideTimer?.cancel();
            _errorShown = false;
            scaffoldMessenger.hideCurrentSnackBar();
            _startPlayback();
          },
        ),
      );

      scaffoldMessenger.showSnackBar(snackBar);

      // 3绉掑后手前姩闅愯棌
      _errorHideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          try {
            scaffoldMessenger.hideCurrentSnackBar();
          } catch (e) {
            ServiceLocator.log.d('PlayerScreen: Error hiding SnackBar: $e');
          }
          _errorShown = false;
        }
      });
    }
  }

  void _startPlayback() {
    _errorShown = false; // 重置错误显示标记
    _errorHideTimer?.cancel(); // 取消错误提示隐藏定时器
    // 隐藏错误提示
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }

    final playerProvider = context.read<PlayerProvider>();
    final channelProvider = context.read<ChannelProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    try {
      // ✅ 使用全部频道列表而不是分页显示的频道，确保能找到当前频道
      final channel = channelProvider.allChannels.firstWhere(
        (c) => c.url == widget.channelUrl,
      );

      // 保存上次播放的频道 ID
      if (settingsProvider.rememberLastChannel && channel.id != null) {
        settingsProvider.setLastChannelId(channel.id);
      }

      playerProvider.playChannel(channel);
    } catch (_) {
      // Fallback if channel object not found
      playerProvider.playUrl(widget.channelUrl, name: widget.channelName);
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  void _showControlsTemporarily() {
    setState(() => _showControls = true);
    _startHideControlsTimer();
  }

  @override
  void dispose() {
    ServiceLocator.log.d(
        'PlayerScreen: dispose() called, _usingNativePlayer=$_usingNativePlayer, _wasMultiScreenMode=$_wasMultiScreenMode');

    // 首先移除 provider 监听器，防止后续更新触发错误显示
    if (_playerProvider != null) {
      _playerProvider!.removeListener(_onProviderUpdate);
    }

    // 然后清除所有错误提示和定时器
    _errorHideTimer?.cancel();
    _errorShown = false;

    // 立即清除所有 SnackBar（包括错误提示）
    // 使用 didChangeDependencies 中提前保存的引用，避免在 dispose 阶段
    // 调用 ScaffoldMessenger.of(context) 触发 deactivated ancestor 错误。
    try {
      _scaffoldMessenger?.clearSnackBars();
    } catch (e) {
      ServiceLocator.log
          .d('PlayerScreen: Error clearing SnackBars in dispose: $e');
    }

    WidgetsBinding.instance.removeObserver(this);
    _hideControlsTimer?.cancel();
    _dlnaSyncTimer?.cancel();
    _wakelockTimer?.cancel();
    _longPressTimer?.cancel();
    _playerFocusNode.dispose();
    _categoryScrollController.dispose();
    _channelScrollController.dispose();

    // 如果是 Windows mini 模式，退出 mini 模式
    if (WindowsPipChannel.isInPipMode) {
      WindowsPipChannel.exitPipMode();
    }

    // 如果是全屏模式，退出全屏 - 使用原生 API
    // 注意：不能在 dispose 期间直接调用 SetWindowPos，否则会触发
    // Flutter 帧调度断言失败（_schedulerPhase == midFrameMicrotasks）
    // 延迟到下一帧执行窗口操作
    if (_isFullScreen && PlatformDetector.isWindows) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final success = WindowsFullscreenNative.exitFullScreen();
        if (!success) {
          ServiceLocator.log
              .d('Native exitFullScreen failed, using window_manager');
          windowManager.setFullScreen(false);
        }
      });
    }

    // 保存分屏状态（Windows 平台）
    if (_wasMultiScreenMode && PlatformDetector.isDesktop) {
      _saveMultiScreenState();
    }

    // 离开播放页面时，单屏和多屏都必须停止并释放资源
    if (!_usingNativePlayer && _playerProvider != null) {
      ServiceLocator.log
          .d('PlayerScreen: calling _playerProvider.stop() in silent mode');
      // 如果正在回放，先恢复到直播频道对象（虽然即将销毁，但保持状态一致性）
      if (_originalChannel != null) {
        // We don't need to actually play it, just ensure we don't leave mess
        _originalChannel = null;
        _currentCatchupProgram = null;
      }
      unawaited(_playerProvider!.stop(silent: true));
    }
    if (PlatformDetector.isDesktop && _multiScreenProvider != null) {
      ServiceLocator.log.d(
          'PlayerScreen: calling _multiScreenProvider.clearAllScreens() in dispose');
      unawaited(_multiScreenProvider!.clearAllScreens());
    }

    // 重置亮度到系统默认
    try {
      ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {}

    // 全抽棴屏箷甯镐寒
    if (PlatformDetector.isMobile) {
      PlatformDetector.setKeepScreenOn(false);
    } else {
      try {
        WakelockPlus.disable();
      } catch (e) {
        ServiceLocator.log.d('PlayerScreen: Failed to disable wakelock: $e');
      }
    }

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // 恢复到应用设置的屏幕方向 (手机端)
    if (PlatformDetector.isMobile && _settingsProvider != null) {
      final orientation = _settingsProvider!.mobileOrientation;
      List<DeviceOrientation> orientations;

      switch (orientation) {
        case 'portrait':
          orientations = [
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ];
          break;
        case 'landscape':
          orientations = [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ];
          break;
        case 'auto':
        default:
          orientations = [
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ];
          break;
      }

      SystemChrome.setPreferredOrientations(orientations);
    }

    super.dispose();
  }

  /// 保存分屏状态（Windows 平台）
  void _saveMultiScreenState() {
    // 避免重复保存
    if (_multiScreenStateSaved) {
      ServiceLocator.log
          .d('PlayerScreen: Multi-screen state already saved, skipping');
      return;
    }

    try {
      if (_multiScreenProvider == null || _settingsProvider == null) {
        ServiceLocator.log.d(
            'PlayerScreen: Cannot save multi-screen state - providers not available');
        return;
      }

      // 获取每个屏幕的频道ID
      final List<int?> channelIds = [];
      final List<int> sourceIndexes = [];
      for (int i = 0; i < 4; i++) {
        final screen = _multiScreenProvider!.getScreen(i);
        channelIds.add(screen.channel?.id);
        sourceIndexes.add(screen.channel?.currentSourceIndex ?? 0);
      }

      final activeIndex = _multiScreenProvider!.activeScreenIndex;

      ServiceLocator.log.d(
          'PlayerScreen: Saving multi-screen state - channelIds: $channelIds, sourceIndexes: $sourceIndexes, activeIndex: $activeIndex');

      // 保存分屏状态
      _settingsProvider!.saveLastMultiScreen(
        channelIds,
        activeIndex,
        sourceIndexes: sourceIndexes,
      );
      _multiScreenStateSaved = true;
    } catch (e) {
      ServiceLocator.log.d('PlayerScreen: Error saving multi-screen state: $e');
    }
  }

  /// 显示源切换指示器 (已移除，因为顶部已有显示)
  void _showSourceSwitchIndicator(PlayerProvider provider) {
    // 不再显示 SnackBar，顶部已有源指示器
  }

  void _saveLastChannelId(Channel? channel) {
    // Don't save if it's a catchup channel (temporary)
    if (_originalChannel != null) return;

    if (channel == null || channel.id == null) return;
    if (_settingsProvider != null && _settingsProvider!.rememberLastChannel) {
      // 保存单频道播放状态
      _settingsProvider!.saveLastSingleChannel(channel.id);
    }
  }

  /// 切换屏幕方向 (横屏 <-> 竖屏) - 仅手机端
  Future<void> _toggleOrientation() async {
    if (!PlatformDetector.isMobile) return;

    // 判断当前方向,切换到相反方向
    final isPortrait = _currentOrientation == DeviceOrientation.portraitUp;

    final newOrientation = isPortrait
        ? DeviceOrientation.landscapeLeft
        : DeviceOrientation.portraitUp;

    // 应用新方向
    await SystemChrome.setPreferredOrientations([newOrientation]);

    // 更新状态
    setState(() {
      _currentOrientation = newOrientation;
    });

    // 显示简短提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPortrait ? '已切换到横屏' : '已切换到竖屏',
          ),
          duration: const Duration(milliseconds: 800),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 构建屏幕方向切换悬浮按钮
  Widget _buildOrientationFab() {
    IconData icon;
    String tooltip;

    // 根据当前方向显示对应图标
    if (_currentOrientation == DeviceOrientation.portraitUp) {
      icon = Icons.screen_rotation_rounded;
      tooltip = '切换到横屏';
    } else {
      icon = Icons.stay_current_portrait_rounded;
      tooltip = '切换到竖屏';
    }

    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 120), // 向上偏移120像素,避免遮挡底部控制栏
        child: FloatingActionButton(
          mini: true,
          backgroundColor: Colors.black.withOpacity(0.6),
          onPressed: _toggleOrientation,
          tooltip: tooltip,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  // ============ 手机端手动控制============

  // 简化手动控制
  Offset? _panStartPosition;
  String?
      _currentGestureType; // 'volume', 'brightness', 'channel', 'horizontal'

  void _onPanStart(DragStartDetails details) {
    _panStartPosition = details.globalPosition;
    _currentGestureType = null;

    final playerProvider = _playerProvider ?? context.read<PlayerProvider>();
    _initialVolume = playerProvider.volume;
    _gestureStartY = details.globalPosition.dy;

    // 异步获取当前亮度
    _loadCurrentBrightness();
  }

  Future<void> _loadCurrentBrightness() async {
    try {
      _initialBrightness = await ScreenBrightness.instance.current;
    } catch (_) {
      _initialBrightness = 0.5;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_panStartPosition == null) return;

    final dx = details.globalPosition.dx - _panStartPosition!.dx;
    final dy = details.globalPosition.dy - _panStartPosition!.dy;

    // 首次移动超过阈值时确定手势类型
    if (_currentGestureType == null) {
      const threshold = 10.0; // 降低阈值，更灵敏
      if (dx.abs() > threshold || dy.abs() > threshold) {
        final screenWidth = MediaQuery.of(context).size.width;
        final x = _panStartPosition!.dx;

        if (dy.abs() > dx.abs()) {
          // 垂直滑动
          if (x < screenWidth * 0.35) {
            _currentGestureType = 'volume';
            _gestureValue = _initialVolume;
          } else if (x > screenWidth * 0.65) {
            _currentGestureType = 'brightness';
            _gestureValue = _initialBrightness;
          } else {
            _currentGestureType = 'channel';
          }
        } else {
          // 水平滑动
          _currentGestureType = 'horizontal';
        }
      }
      return;
    }

    // 处理垂直滑动
    final screenHeight = MediaQuery.of(context).size.height;
    final deltaY = _gestureStartY - details.globalPosition.dy;

    if (_currentGestureType == 'volume') {
      final volumeChange =
          (deltaY / (screenHeight * 0.5)) * 1.0; // 滑动半屏改变100%音量
      final newVolume = (_initialVolume + volumeChange).clamp(0.0, 1.0);
      (_playerProvider ?? context.read<PlayerProvider>()).setVolume(newVolume);
      setState(() {
        _showGestureIndicator = true;
        _gestureValue = newVolume;
      });
    } else if (_currentGestureType == 'brightness') {
      final brightnessChange = (deltaY / (screenHeight * 0.5)) * 1.0;
      final newBrightness =
          (_initialBrightness + brightnessChange).clamp(0.0, 1.0);
      try {
        ScreenBrightness.instance.setApplicationScreenBrightness(newBrightness);
      } catch (_) {}
      setState(() {
        _showGestureIndicator = true;
        _gestureValue = newBrightness;
      });
    } else if (_currentGestureType == 'channel') {
      // 中间区域显示滑动指示
      setState(() {
        _showGestureIndicator = true;
        _gestureValue = dy.clamp(-100.0, 100.0) / 100.0; // 用于显示方向
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_panStartPosition == null) {
      _resetGestureState();
      return;
    }

    final dx = details.globalPosition.dx - _panStartPosition!.dx;
    final dy = details.globalPosition.dy - _panStartPosition!.dy;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // 处理频道切换
    if (_currentGestureType == 'channel') {
      final threshold = screenHeight * 0.08; // 滑动超过屏幕8%才可以切换
      if (dy.abs() > threshold) {
        _errorShown = false; // 切换频道时重置错误标记
        _errorHideTimer?.cancel(); // 取消错误提示隐藏定时器
        // 隐藏错误提示
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        final playerProvider =
            _playerProvider ?? context.read<PlayerProvider>();
        final channelProvider = context.read<ChannelProvider>();
        if (dy > 0) {
          // 下滑 -> 上一个频道
          playerProvider.playPrevious(channelProvider.allChannels);
          _saveLastChannelId(playerProvider.currentChannel);
        } else {
          // 上滑 -> 下一个频道
          playerProvider.playNext(channelProvider.allChannels);
          _saveLastChannelId(playerProvider.currentChannel);
        }
        // 强制刷新 UI
        setState(() {});
      }
    }

    // 处理水平滑动 - 显示/隐藏分类菜单
    if (_currentGestureType == 'horizontal') {
      final threshold = screenWidth * 0.15; // 滑动超过屏幕15%
      if (dx < -threshold && !_showCategoryPanel && !_showEpgPanel) {
        // 宸︽粦显示切嗙被鑿滃崟
        setState(() {
          _showCategoryPanel = true;
          _showControls = false;
        });
      } else if (dx > threshold) {
        if (_showCategoryPanel) {
          // Close category panel
          setState(() {
            _showCategoryPanel = false;
            _selectedCategory = null;
          });
        } else if (_showEpgPanel) {
          // Close EPG panel (swipe right)
          setState(() {
            _showEpgPanel = false;
          });
        }
      } else if (dx < -threshold && !_showCategoryPanel && _showEpgPanel) {
        // Swipe left when EPG is open? Maybe nothing or keep open.
      } else if (dx < -threshold && !_showCategoryPanel && !_showEpgPanel) {
        // Open EPG? No, left swipe opens Category (left panel).
        // Right swipe could open EPG (right panel)?
        // Current logic: Left Swipe (dx < 0) -> Open Left Panel (Category)
        // Right Swipe (dx > 0) -> Close Left Panel

        // Let's add: Right Swipe from right edge -> Open EPG?
        // Or just use button for EPG.
      }
    }

    _resetGestureState();
  }

  // EPG Playback Logic
  void _playCatchup(EpgProgram program) {
    final currentChannel = _playerProvider?.currentChannel;
    if (currentChannel == null) return;

    // Store original channel if not already playing catchup
    _originalChannel ??= currentChannel;

    // Determine the source channel (should be the original one)
    final sourceChannel = _originalChannel!;

    // Generate catchup URL
    final catchupUrl = _generateCatchupUrl(sourceChannel, program);
    if (catchupUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to generate playback URL')),
      );
      return;
    }

    // Create temporary channel for playback
    // Force type to replay by setting group name to include "replay" or "catchup"
    // Or just rely on isSeekable override (not possible easily)
    // But ChannelType logic checks for 'catchup' in group.
    final playbackChannel = sourceChannel.copyWith(
      url: catchupUrl,
      // Important: Must update sources list to contain the catchup URL!
      // Otherwise PlayerProvider will use the original source (live stream)
      sources: [catchupUrl],
      // Append catchup to group to ensure it's treated as replay
      groupName: '${sourceChannel.groupName} [Catchup]',
      catchup: 'active', // Mark as active catchup
    );

    // Play it
    _currentCatchupProgram = program;
    // Calculate and set override duration
    final duration = program.end.difference(program.start);
    _playerProvider?.setOverrideDuration(duration);

    _playerProvider?.playChannel(playbackChannel);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing catchup: ${program.title}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _backToLive() {
    if (_originalChannel != null) {
      _playerProvider?.playChannel(_originalChannel!);
      _originalChannel = null;
      _currentCatchupProgram = null;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Returned to live stream'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  String? _generateCatchupUrl(Channel channel, EpgProgram program) {
    if (channel.catchupSource == null) return null;

    // catchup 模式：default（占位符替换）、append（URL 追加）、shift（偏移）
    final catchupMode = channel.catchup?.toLowerCase() ?? 'default';

    // IMPORTANT: program.start and program.end are LOCAL time (converted in EPG parser)
    // They match what user sees in EPG UI.
    final startLocal = program.start;
    final endLocal = program.end;
    final startUtc = startLocal.toUtc();
    final endUtc = endLocal.toUtc();

    // ISO 8601 format (UTC): yyyy-MM-ddTHH:mm:ssZ - for ${start}, ${stop}, ${end}
    final startIso = startUtc.toIso8601String();
    final startIsoClean = startIso.replaceAll(RegExp(r'\.\d+Z$'), 'Z');
    final endIso = endUtc.toIso8601String();
    final endIsoClean = endIso.replaceAll(RegExp(r'\.\d+Z$'), 'Z');

    // Unix 秒级 UTC 时间戳（Kodi pvr.iptvsimple 事实标准）for ${utc}, ${utcend}, {utc}, {utcend}
    final startSec = startUtc.millisecondsSinceEpoch ~/ 1000;
    final endSec = endUtc.millisecondsSinceEpoch ~/ 1000;
    // 时长（秒）for ${duration}
    final durationSec = endUtc.difference(startUtc).inSeconds;

    // 当前时刻（UTC）— 对齐 rtp2httpd 的 ${lutc}/${now}/${timestamp}/${offset}
    final now = DateTime.now().toUtc();
    final nowSec = now.millisecondsSinceEpoch ~/ 1000;
    final nowIso = now.toIso8601String().replaceAll(RegExp(r'\.\d+Z$'), 'Z');
    // 距节目开始的偏移（秒）for ${offset}
    final offsetSec = nowSec - startSec;

    var url = channel.catchupSource!;

    // Step 1: Handle custom date format patterns with timezone support
    // Pattern variations:
    //   ${(b)yyyyMMddHHmmss}        -> begin/start, LOCAL time (matches EPG display)
    //   ${(e)yyyyMMddHHmmss}        -> end, LOCAL time
    //   ${(bu)yyyyMMddHHmmss}       -> begin/start, UTC time (explicit UTC, prefix u)
    //   ${(eu)yyyyMMddHHmmss}       -> end, UTC time
    //   ${(b)yyyyMMddHHmmss:UTC}    -> begin/start, UTC time (Kodi :UTC suffix)
    //   ${(e)yyyyMMddHHmmss:UTC}    -> end, UTC time
    //   ${(B)...} / ${(E)...}       -> uppercase variants as aliases
    // 匹配前缀 u 或后缀 :UTC 两种时区标记，并将 `:UTC` 从格式串中剔除
    final customFormatRegex =
        RegExp(r'\$\{\(([bBeE])([uU]?)\)([A-Za-z:"\u0027]+)(?::UTC)?\}');
    final customMatches = customFormatRegex.allMatches(url);
    for (final match in customMatches) {
      final timeMarker = match.group(1)!.toLowerCase(); // 'b' or 'e'
      final tzMarker = match.group(2)!.toLowerCase();   // 'u' or ''
      // 格式串可能自带 :UTC 后缀（如 yyyyMMddHHmmss:UTC），需剔除后再格式化
      var formatStr = match.group(3)!;
      final hasUtcSuffix = formatStr.endsWith(':UTC');
      if (hasUtcSuffix) {
        formatStr = formatStr.substring(0, formatStr.length - 4);
      }

      // Choose local or UTC datetime: 前缀 u 或后缀 :UTC 均按 UTC 处理
      final useUtc = tzMarker == 'u' || hasUtcSuffix;
      DateTime dateTime;
      if (useUtc) {
        // Explicit UTC requested
        dateTime = (timeMarker == 'b') ? startUtc : endUtc;
      } else {
        // Default: use LOCAL time to match EPG display
        dateTime = (timeMarker == 'b') ? startLocal : endLocal;
      }

      try {
        final formatter = DateFormat(formatStr);
        final formatted = formatter.format(dateTime);
        url = url.replaceFirst(match.group(0)!, formatted);
      } catch (_) {
        // If DateFormat fails, skip this replacement (keep original pattern)
      }
    }

    // Also handle brace-only version: {(b)yyyyMMddHHmmss}, {(bu)yyyyMMddHHmmss}, {(b)...:UTC}
    final braceFormatRegex =
        RegExp(r'\{\(([bBeE])([uU]?)\)([^}]+)\}');
    final braceMatches = braceFormatRegex.allMatches(url);
    for (final match in braceMatches) {
      final timeMarker = match.group(1)!.toLowerCase();
      final tzMarker = match.group(2)!.toLowerCase();
      var formatStr = match.group(3)!;
      final hasUtcSuffix = formatStr.endsWith(':UTC');
      if (hasUtcSuffix) {
        formatStr = formatStr.substring(0, formatStr.length - 4);
      }
      final useUtc = tzMarker == 'u' || hasUtcSuffix;
      DateTime dateTime;
      if (useUtc) {
        dateTime = (timeMarker == 'b') ? startUtc : endUtc;
      } else {
        dateTime = (timeMarker == 'b') ? startLocal : endLocal;
      }
      try {
        final formatter = DateFormat(formatStr);
        final formatted = formatter.format(dateTime);
        url = url.replaceFirst(match.group(0)!, formatted);
      } catch (_) {}
    }

    // Step 2: Handle standard ${start}/${stop}/${end} patterns. 保持 ISO 8601 (UTC) 兼容
    // ISO format with 'Z' suffix always means UTC - this is the standard behavior
    url = url.replaceAll(RegExp(r'\$\{start\}'), startIsoClean);
    url = url.replaceAll(RegExp(r'\$\{stop\}'), endIsoClean);
    url = url.replaceAll(RegExp(r'\$\{end\}'), endIsoClean);

    // Handle {start}/{stop}/{end}
    url = url.replaceAll(RegExp(r'\{start\}'), startIsoClean);
    url = url.replaceAll(RegExp(r'\{stop\}'), endIsoClean);
    url = url.replaceAll(RegExp(r'\{end\}'), endIsoClean);

    // Step 2.4: 对齐 rtp2httpd 的「关键字:格式」占位符 — 用指定格式串渲染时间
    //   ${utc:yyyyMMdd} / {utc:yyyyMMdd}   -> 节目开始时间（UTC）
    //   ${utcend:yyyyMMdd} / {utcend:...}  -> 节目结束时间（UTC）
    //   ${start:格式} / ${end:格式}         -> 开始/结束（UTC）
    //   ${lutc:格式} / ${now:格式} / ${timestamp:格式} -> 当前时刻（UTC）
    void applyKeywordFormat(RegExp regex) {
      for (final match in regex.allMatches(url).toList()) {
        final keyword = match.group(1)!.toLowerCase();
        final fmt = match.group(2)!;
        DateTime? target;
        if (keyword == 'utc' || keyword == 'start' || keyword == 'yyyy' || keyword == 'MM' ||
            keyword == 'dd' || keyword == 'HH' || keyword == 'mm' || keyword == 'ss') {
          target = startUtc;
        } else if (keyword == 'utcend' || keyword == 'end') {
          target = endUtc;
        } else if (keyword == 'lutc' || keyword == 'now' || keyword == 'timestamp') {
          target = now;
        }
        if (target == null) continue;
        try {
          final formatted = DateFormat(fmt).format(target);
          url = url.replaceFirst(match.group(0)!, formatted);
        } catch (_) {}
      }
    }
    applyKeywordFormat(RegExp(r'\$\{(\w+):([^}]+)\}'));
    applyKeywordFormat(RegExp(r'\{(\w+):([^}]+)\}'));

    // Step 2.5: 行业标准占位符（Kodi pvr.iptvsimple 规范）— Unix 秒级 UTC 时间戳
    //   ${utc}        -> 节目开始时间（Unix 秒，UTC）
    //   ${utcend}     -> 节目结束时间（Unix 秒，UTC）
    //   ${timestamp}  -> 当前时刻（Unix 秒，UTC）— 对齐 rtp2httpd
    //   ${duration}   -> 节目时长（秒）
    //   ${offset}     -> 当前时刻 - 节目开始（秒）— 对齐 rtp2httpd
    //   ${lutc}/${now}-> 当前时刻（完整 ISO+Z）— 对齐 rtp2httpd
    url = url.replaceAll(RegExp(r'\$\{utc\}'), startSec.toString());
    url = url.replaceAll(RegExp(r'\$\{utcend\}'), endSec.toString());
    url = url.replaceAll(RegExp(r'\$\{timestamp\}'), nowSec.toString());
    url = url.replaceAll(RegExp(r'\$\{duration\}'), durationSec.toString());
    url = url.replaceAll(RegExp(r'\$\{offset\}'), offsetSec.toString());
    url = url.replaceAll(RegExp(r'\$\{lutc\}'), nowIso);
    url = url.replaceAll(RegExp(r'\$\{now\}'), nowIso);
    // 大括号版本
    url = url.replaceAll(RegExp(r'\{utc\}'), startSec.toString());
    url = url.replaceAll(RegExp(r'\{utcend\}'), endSec.toString());
    url = url.replaceAll(RegExp(r'\{timestamp\}'), nowSec.toString());
    url = url.replaceAll(RegExp(r'\{duration\}'), durationSec.toString());
    url = url.replaceAll(RegExp(r'\{offset\}'), offsetSec.toString());
    url = url.replaceAll(RegExp(r'\{lutc\}'), nowIso);
    url = url.replaceAll(RegExp(r'\{now\}'), nowIso);

    // Step 2.6: 时间分量占位符（对齐 rtp2httpd）— 均取节目开始时间（UTC）
    //   长格式：${yyyy}/${MM}/${dd}/${HH}/${mm}/${ss}
    //   短格式（brace-only）：{Y}/{m}/{d}/{H}/{M}/{S}
    final compYear = DateFormat('yyyy').format(startUtc);
    final compMonth = DateFormat('MM').format(startUtc);
    final compDay = DateFormat('dd').format(startUtc);
    final compHour = DateFormat('HH').format(startUtc);
    final compMinute = DateFormat('mm').format(startUtc);
    final compSecond = DateFormat('ss').format(startUtc);
    url = url.replaceAll(RegExp(r'\$\{yyyy\}'), compYear);
    url = url.replaceAll(RegExp(r'\$\{MM\}'), compMonth);
    url = url.replaceAll(RegExp(r'\$\{dd\}'), compDay);
    url = url.replaceAll(RegExp(r'\$\{HH\}'), compHour);
    url = url.replaceAll(RegExp(r'\$\{mm\}'), compMinute);
    url = url.replaceAll(RegExp(r'\$\{ss\}'), compSecond);
    url = url.replaceAll(RegExp(r'\{Y\}'), compYear);
    url = url.replaceAll(RegExp(r'\{m\}'), compMonth);
    url = url.replaceAll(RegExp(r'\{d\}'), compDay);
    url = url.replaceAll(RegExp(r'\{H\}'), compHour);
    url = url.replaceAll(RegExp(r'\{M\}'), compMinute);
    url = url.replaceAll(RegExp(r'\{S\}'), compSecond);

    // Step 3: append 模式 — 在直播 URL 上追加 catchup-source 参数片段
    // Xtream 规范：catchup="append" 时，catchup-source 是待追加的参数模板
    // （如 &starttime={utc}&endtime={utcend}），拼接到原始直播地址末尾形成回看 URL。
    // 注意：{utc}/{utcend}/{duration}/{timestamp} 等占位符已由 Step 1/2/2.5 统一替换
    if (catchupMode == 'append') {
      return channel.url + url;
    }

    return url;
  }

  void _resetGestureState() {
    setState(() {
      _showGestureIndicator = false;
    });
    _panStartPosition = null;
    _currentGestureType = null;
  }


  DateTime? _lastSelectKeyDownTime;
  DateTime? _lastLeftKeyDownTime; // 用于检测长按左键
  Timer? _longPressTimer; // 长按定时器

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    _showControlsTemporarily();

    final playerProvider = context.read<PlayerProvider>();
    final key = event.logicalKey;

    // Play/Pause & Favorite (Select/Enter)
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) {
        if (event is KeyRepeatEvent) return KeyEventResult.handled;
        _lastSelectKeyDownTime = DateTime.now();
        return KeyEventResult.handled;
      }

      if (event is KeyUpEvent && _lastSelectKeyDownTime != null) {
        final duration = DateTime.now().difference(_lastSelectKeyDownTime!);
        _lastSelectKeyDownTime = null;

        if (duration.inMilliseconds > 500) {
          // Long Press: Toggle Favorite
          // Channel Provider not needed, Favorites Provider is enough
          // final provider = context.read<ChannelProvider>();
          final favorites = context.read<FavoritesProvider>();
          final channel = playerProvider.currentChannel;

          if (channel != null) {
            favorites.toggleFavorite(channel);

            // Show toast
            final isFav = favorites.isFavorite(channel.id ?? 0);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isFav ? 'Added to Favorites' : 'Removed from Favorites',
                ),
                duration: const Duration(seconds: 1),
                backgroundColor: AppTheme.accentColor,
              ),
            );
          }
        } else {
          // Short Press: Play/Pause or Select Button if focused?
          // Actually, if we are focused on a button, the button handles it?
          // No, we are in the Parent Focus Capture.
          // If we handle it here, the child button's 'onSelect' might not trigger if we consume it?
          // Focus on the scaffold body is _playerFocusNode.
          // If focus is on a button, this _handleKeyEvent on _playerFocusNode might NOT receive it if the button consumes it?
          // Wait, Focus(onKeyEvent) usually bubbles UP if not handled by child.
          // If the child (button) handles it, this won't run.
          // So this logic only applies when no button handles it (e.g. video area focused).
          playerProvider.togglePlayPause();
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    // Left key - 切换到上一个源 / 长按打开分类面板
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (event is KeyDownEvent) {
        if (event is KeyRepeatEvent) return KeyEventResult.handled;
        _lastLeftKeyDownTime = DateTime.now();
        // 启动长按定时器
        _longPressTimer?.cancel();
        _longPressTimer = Timer(const Duration(milliseconds: 500), () {
          if (mounted && _lastLeftKeyDownTime != null) {
            // 长按：打开分类面板并定位到当前频道
            final playerProvider = context.read<PlayerProvider>();
            final channelProvider = context.read<ChannelProvider>();
            final currentChannel = playerProvider.currentChannel;

            setState(() {
              _showCategoryPanel = true;
              // 如果有当前频道，自动选中其所属分类
              if (currentChannel != null && currentChannel.groupName != null) {
                _selectedCategory = currentChannel.groupName;

                // 延迟滚动到当前频道位置
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_selectedCategory != null) {
                    final channels =
                        channelProvider.getChannelsByGroup(_selectedCategory!);
                    final currentIndex =
                        channels.indexWhere((ch) => ch.id == currentChannel.id);

                    if (currentIndex >= 0 &&
                        _channelScrollController.hasClients) {
                      // 计算滚动位置（每个频道项高 44 像素高）
                      const itemHeight = 44.0;
                      final scrollOffset = currentIndex * itemHeight;

                      _channelScrollController.animateTo(
                        scrollOffset,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  }
                });
              } else {
                _selectedCategory = null;
              }
            });
            _lastLeftKeyDownTime = null; // 标记已处理长按
          }
        });
        return KeyEventResult.handled;
      }

      if (event is KeyUpEvent) {
        _longPressTimer?.cancel();
        if (_lastLeftKeyDownTime != null) {
          // 短按：切换上一个源或重新显示分类面板
          _lastLeftKeyDownTime = null;

          if (_showCategoryPanel) {
            // 如果分屏面板已显示且在频道列表，返回分类列表
            if (_selectedCategory != null) {
              setState(() => _selectedCategory = null);
              return KeyEventResult.handled;
            }
            // 如果在分类列表，关闭面板
            setState(() {
              _showCategoryPanel = false;
              _selectedCategory = null;
            });
            return KeyEventResult.handled;
          }

          if (_showEpgPanel) {
            setState(() => _showEpgPanel = false);
            return KeyEventResult.handled;
          }

          // 切换到上一个源
          final channel = playerProvider.currentChannel;
          if (channel != null && channel.hasMultipleSources) {
            playerProvider.switchToPreviousSource();
            _showSourceSwitchIndicator(playerProvider);
          }
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    // Right key - 切换到下一个源
    if (key == LogicalKeyboardKey.arrowRight) {
      if (_showCategoryPanel) {
        // 如果在分类面板，按键不做任何事
        return KeyEventResult.handled;
      }

      if (_showEpgPanel) {
        // EPG panel is focused/active
        return KeyEventResult.handled;
      }

      if (event is KeyDownEvent && event is! KeyRepeatEvent) {
        // 切换到下一个源
        final channel = playerProvider.currentChannel;
        if (channel != null && channel.hasMultipleSources) {
          playerProvider.switchToNextSource();
          _showSourceSwitchIndicator(playerProvider);
        }
      }
      return KeyEventResult.handled;
    }

    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    // I will keep Up/Down as Channel Switch for now, unless user explicitly requested navigation.
    // Wait, user complained "Navigate bar displays, Left/Right cannot seek (should move focus)".
    // They didn't complain about Up/Down. So I will ONLY modify Left/Right.

    // Previous Channel (Up)
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.channelUp) {
      _errorShown = false; // 切换频道时重置错误标记
      _errorHideTimer?.cancel(); // 取消错误提示隐藏定时器
      // 隐藏错误提示
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final channelProvider = context.read<ChannelProvider>();
      playerProvider.playPrevious(channelProvider.allChannels);
      // 保存上次播放的频道 ID
      _saveLastChannelId(playerProvider.currentChannel);
      return KeyEventResult.handled;
    }

    // Next Channel (Down)
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.channelDown) {
      _errorShown = false; // 切换频道时重置错误标记
      _errorHideTimer?.cancel(); // 取消错误提示隐藏定时器
      // 隐藏错误提示
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final channelProvider = context.read<ChannelProvider>();
      playerProvider.playNext(channelProvider.allChannels);
      // 保存上次播放的频道 ID
      _saveLastChannelId(playerProvider.currentChannel);
      return KeyEventResult.handled;
    }

    // Back/Exit
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      // 沉浸模式下先退出迷你模式
      if (WindowsPipChannel.isInPipMode) {
        WindowsPipChannel.exitPipMode();
        setState(() {});
        // 恢复焦点到播放器
        _playerFocusNode.requestFocus();
        return KeyEventResult.handled;
      }

      // 先清除所有错误提示和状态
      _errorHideTimer?.cancel();
      _errorShown = false;
      ScaffoldMessenger.of(context).clearSnackBars();

      // 不需要手动调用 stop()，dispose 会自动处理
      // 直接返回即可，dispose 会在页面销毁时调用

      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      return KeyEventResult.handled;
    }

    // Mute - 只在 TV 端处理
    if (key == LogicalKeyboardKey.keyM ||
        (key == LogicalKeyboardKey.audioVolumeMute &&
            !PlatformDetector.isMobile)) {
      playerProvider.toggleMute();
      return KeyEventResult.handled;
    }

    // Explicit Volume Keys (for TV remotes with dedicated buttons)
    // 手机端让系统处理音量键
    if (!PlatformDetector.isMobile) {
      if (key == LogicalKeyboardKey.audioVolumeUp) {
        playerProvider.setVolume(playerProvider.volume + 0.1);
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.audioVolumeDown) {
        playerProvider.setVolume(playerProvider.volume - 0.1);
        return KeyEventResult.handled;
      }
    }

    // Settings / Menu
    if (key == LogicalKeyboardKey.settings ||
        key == LogicalKeyboardKey.contextMenu) {
      _showSettingsSheet(context);
      return KeyEventResult.handled;
    }

    // Back (explicit handling for some remotes)
    if (key == LogicalKeyboardKey.backspace) {
      ServiceLocator.log.d('========================================');
      ServiceLocator.log.d('PlayerScreen: Back key pressed (backspace)');

      // 先清除所有错误提示和状态
      ServiceLocator.log.d('PlayerScreen: Clearing error state');
      _errorHideTimer?.cancel();
      _errorShown = false;
      ScaffoldMessenger.of(context).clearSnackBars();
      ServiceLocator.log.d('PlayerScreen: SnackBars cleared');

      // 不需要手动调用 stop()，dispose 会自动处理
      ServiceLocator.log
          .d('PlayerScreen: Navigating back (stop will be called in dispose)');

      if (Navigator.canPop(context)) {
        ServiceLocator.log.d('PlayerScreen: Popping navigation');
        Navigator.of(context).pop();
      }
      ServiceLocator.log.d('========================================');
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // 椤甸潰宸茬粡 pop锛岀珛启虫竻闄ら敊璇彁绀?
          _errorHideTimer?.cancel();
          _errorShown = false;
          try {
            ScaffoldMessenger.of(context).clearSnackBars();
          } catch (e) {
            ServiceLocator.log.d(
                'PlayerScreen: Error clearing SnackBars in onPopInvoked: $e');
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        floatingActionButton: (PlatformDetector.isMobile && _showControls)
            ? _buildOrientationFab()
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: Focus(
          focusNode: _playerFocusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: MouseRegion(
            cursor: _showControls
                ? SystemMouseCursors.basic
                : SystemMouseCursors.none,
            onEnter: (_) {
              _mouseOver = true;
              _showControlsTemporarily();
            },
            onHover: (_) {
              _showControlsTemporarily();
            },
            onExit: (_) {
              _mouseOver = false;
              if (mounted) {
                _hideControlsTimer?.cancel();
                _hideControlsTimer =
                    Timer(const Duration(milliseconds: 300), () {
                  if (mounted && !_mouseOver) {
                    setState(() => _showControls = false);
                  }
                });
              }
            },
            child: GestureDetector(
              // 使用 translucent 让子组件也能接收点击事件
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (_showCategoryPanel) {
                  setState(() {
                    _showCategoryPanel = false;
                    _selectedCategory = null;
                  });
                } else if (_showEpgPanel) {
                  setState(() => _showEpgPanel = false);
                } else {
                  _showControlsTemporarily();
                }
              },
              onDoubleTap: () {
                context.read<PlayerProvider>().togglePlayPause();
              },
              // 手机端手动控制 - 使用 Pan 手势统一处理
              onPanStart: PlatformDetector.isMobile ? _onPanStart : null,
              onPanUpdate: PlatformDetector.isMobile ? _onPanUpdate : null,
              onPanEnd: PlatformDetector.isMobile ? _onPanEnd : null,
              child: Stack(
                children: [
                  // 全屏背景，确保手势可以在整个屏幕响应
                  const Positioned.fill(
                    child: ColoredBox(color: Colors.transparent),
                  ),

                  // Video Player
                  _buildVideoPlayer(),

                  // Controls Overlay - 分屏模式下不显示全局控制栏
                  if (!_isMultiScreenMode())
                    AnimatedOpacity(
                      opacity: _showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: IgnorePointer(
                        ignoring: !_showControls,
                        child: WindowsPipChannel.isInPipMode
                            ? MiniControlsOverlay(
                            onRestore: () async {
                              await WindowsPipChannel.exitPipMode();
                              // 延迟同步全屏状态，等待窗口恢复完成
                              if (PlatformDetector.isWindows) {
                                await Future.delayed(
                                    const Duration(milliseconds: 300));
                                _isFullScreen = await windowManager.isFullScreen();
                              }
                              setState(() {});
                              // 恢复焦点到播放器
                              _playerFocusNode.requestFocus();
                            },
                            onClose: () {
                              WindowsPipChannel.exitPipMode();
                              context.read<PlayerProvider>().stop();
                              Navigator.of(context).pop();
                            },
                          )
                            : _buildControlsOverlay(),
                      ),
                    ),

                  // Category Panel (Left side) - 沉浸模式和分屏模式不显示
                  if (_showCategoryPanel &&
                      !WindowsPipChannel.isInPipMode &&
                      !_isMultiScreenMode())
                    _buildCategoryPanel(),

                  // EPG Panel (Right side)
                  _buildEpgPanel(),

                  // 手前娍鎸囩ず器?手嬫満绔?
                  if (_showGestureIndicator)
                          GestureOverlay(
                            gestureType: _currentGestureType,
                            gestureValue: _gestureValue,
                          ),

                  // Loading Indicator - 切嗗睆模式紡个嬩笉显示全ㄥ眬加浇鎸囩ず器?
                  if (_isLoading && !_isMultiScreenMode())
                    Center(
                      child: Transform.scale(
                        scale: WindowsPipChannel.isInPipMode ? 0.6 : 1.0,
                        child: CircularProgressIndicator(
                          color: AppTheme.getPrimaryColor(context),
                        ),
                      ),
                    ),

                  // FPS 显示 - 仅在遥控模式单独显示
                  Builder(
                    builder: (context) {
                      final settings = context.watch<SettingsProvider>();
                      final player = context.watch<PlayerProvider>();

                      // 非全屏模式下由底部组件统一显示
                      if (!WindowsPipChannel.isInPipMode) {
                        return const SizedBox.shrink();
                      }

                      if (!settings.showFps ||
                          player.state != PlayerState.playing) {
                        return const SizedBox.shrink();
                      }
                      final fps = player.currentFps;
                      if (fps <= 0) return const SizedBox.shrink();

                      return Positioned(
                        bottom: 4,
                        right: 4,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              '${fps.toStringAsFixed(0)} FPS',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  PlayerInfoOverlay(
                    isMultiScreen: _isMultiScreenMode(),
                  ),

                  // Error Display - Handled via Listener now to show SnackBar
                  // But we can keep a subtle indicator if needed, or remove it entirely
                  // to prevent blocking. Let's remove the blocking widget.
                ],
              ),
            ),
          ),
        ),
      ),
    ); // PopScope
  }

  // 构建右侧 EPG 面板（沉浸/分屏/PIP 模式下不显示）。
  Widget _buildEpgPanel() {
    if (!_showEpgPanel ||
        WindowsPipChannel.isInPipMode ||
        _isMultiScreenMode()) {
      return const SizedBox.shrink();
    }
    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      child: InteractiveEpgWidget(
        channel: _originalChannel ??
            (_playerProvider?.currentChannel ??
                Channel(playlistId: 0, name: 'Unknown', url: '')),
        isPlayingCatchup: _originalChannel != null,
        currentCatchupProgram: _currentCatchupProgram,
        onProgramSelected: (program) {
          _playCatchup(program);
          setState(() => _showEpgPanel = false);
        },
        onBackToLive: () {
          _backToLive();
          setState(() => _showEpgPanel = false);
        },
      ),
    );
  }

  Widget _buildVideoPlayer() {
    // 使用本地状态判断是否显示分屏模式
    if (_isMultiScreenMode()) {
      return _buildMultiScreenPlayer();
    }

    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        // 已熶竴使用敤 media_kit
        if (provider.videoController == null) {
          return const SizedBox.expand(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return ExcludeSemantics(
          // Exclude semantics from video texture widget to prevent AXTree update
          // errors when the platform video surface rebuilds.
          child: Video(
            controller: provider.videoController!,
            controls: NoVideoControls,
          ),
        );
      },
    );
  }

  // 多屏播放器
  Widget _buildMultiScreenPlayer() {
    return MultiScreenPlayer(
      onExitMultiScreen: () {
        // 退出分屏模式，使用活动屏幕的频道全屏播放（不修改设置）
        final multiScreenProvider = context.read<MultiScreenProvider>();
        final activeChannel = multiScreenProvider.activeChannel;

        // 切回单屏前：释放多屏播放器，但保留每屏频道状态，方便再次进入
        multiScreenProvider.pauseAllScreens();

        // 切换到常规模式
        setState(() {
          _localMultiScreenMode = false;
        });

        if (activeChannel != null) {
          // 使用主播放器播放活动频道
          unawaited(_resumeSingleFromMultiScreen(activeChannel));
        }
      },
      onBack: () async {
        // 先保存分屏状态，再清空
        _saveMultiScreenState();
        // 返回时清空所有分屏（等待完成）
        final multiScreenProvider = context.read<MultiScreenProvider>();
        await multiScreenProvider.clearAllScreens();
        if (mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  // 切换到分屏模式

  Future<void> _resumeSingleFromMultiScreen(Channel activeChannel) async {
    final playerProvider = context.read<PlayerProvider>();
    final channelProvider = context.read<ChannelProvider>();

    // Prefer channel object from ChannelProvider to keep original source list/count.
    final matchedChannel =
        channelProvider.allChannels.cast<Channel?>().firstWhere(
              (c) =>
                  c != null &&
                  ((activeChannel.id != null && c.id == activeChannel.id) ||
                      c.name == activeChannel.name),
              orElse: () => null,
            );

    final baseChannel = matchedChannel ?? activeChannel;
    final targetSourceIndex = activeChannel.currentSourceIndex.clamp(
      0,
      baseChannel.sourceCount - 1,
    );

    if (matchedChannel != null) {
      matchedChannel.currentSourceIndex = targetSourceIndex;
    }

    final resumeChannel = baseChannel.copyWith(
      currentSourceIndex: targetSourceIndex,
    );
    await playerProvider.playChannel(resumeChannel);
  }

  void _switchToMultiScreenMode() {
    if (!PlatformDetector.isDesktop) return;
    final playerProvider = context.read<PlayerProvider>();
    final multiScreenProvider = context.read<MultiScreenProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final currentChannel = playerProvider.currentChannel;

    // 切换到多屏前先暂停单屏播放
    unawaited(playerProvider.stop(silent: true));

    // 设置音噺澧炲己切板垎灞廝rovider
    multiScreenProvider.setVolumeSettings(
        playerProvider.volume, settingsProvider.volumeBoost);

    // 切换到分屏模式
    setState(() {
      _localMultiScreenMode = true;
    });

    // 如果分屏有记住的频道，恢复播放
    if (multiScreenProvider.hasAnyChannel) {
      multiScreenProvider.resumeAllScreens();
      // 如果有当前频道，更新活动屏幕为当前频道（保留源索引）
      if (currentChannel != null) {
        final activeIndex = multiScreenProvider.activeScreenIndex;
        multiScreenProvider.playChannelOnScreen(activeIndex, currentChannel);
      }
    } else if (currentChannel != null) {
      // 否则如果有当前频道，在默认位置播放
      final defaultPosition = settingsProvider.defaultScreenPosition;
      multiScreenProvider.playChannelAtDefaultPosition(
          currentChannel, defaultPosition);
    }
  }

  // 遥控器模式的简化控制

  Widget _buildControlsOverlay() {
    return Stack(
      children: [
        // Top gradient mask
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 160,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xCC000000), // 80% black
                  Color(0x66000000), // 40% black
                  Colors.transparent,
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        // Bottom gradient mask
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 200,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0x80000000), // 50% black
                  Color(0xE6000000), // 90% black
                ],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),
        ),
        // Content
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
PlayerTopBar(
                fallbackChannelName: widget.channelName,
                onBack: _handleTopBarBack,
                pipButton: WindowsPipChannel.isSupported
                    ? _buildPipButton()
                    : null,
                multiScreenButton: PlatformDetector.isDesktop
                    ? _buildMultiScreenButton()
                    : null,
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SingleChildScrollView(
                    child: _buildBottomControls(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 顶栏返回按钮回调：清理错误提示、退出全屏并返回上一页
  Future<void> _handleTopBarBack() async {
    // 先清除所有错误提示和状态
    _errorHideTimer?.cancel();
    _errorShown = false;
    ScaffoldMessenger.of(context).clearSnackBars();

    // 如果是全屏状态，先退出全屏 - 使用原生 API
    if (_isFullScreen && PlatformDetector.isWindows) {
      _isFullScreen = false;
      final success = WindowsFullscreenNative.exitFullScreen();
      if (!success) {
        // 如果原生 API 失败，回退到 window_manager
        unawaited(windowManager.setFullScreen(false));
      }
    }

    // 不需要手动调用 stop()，dispose 会自动处理

    // 最后导航返回
    if (mounted) {
      Navigator.of(context).pop();
    }
  }


  // 多屏模式切换按钮
  Widget _buildMultiScreenButton() {
    return TVFocusable(
      onSelect: _switchToMultiScreenMode,
      focusScale: 1.0,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isFocused
                ? AppTheme.getPrimaryColor(context)
                : const Color(0x33FFFFFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFocused
                  ? AppTheme.getPrimaryColor(context)
                  : const Color(0x1AFFFFFF),
              width: isFocused ? 2 : 1,
            ),
          ),
          child: child,
        );
      },
      child: const Icon(
        Icons.grid_view_rounded,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  // PiP 画中画播放器按钮
  Widget _buildPipButton() {
    return StatefulBuilder(
      builder: (context, setState) {
        final isInPip = WindowsPipChannel.isInPipMode;
        final isPinned = WindowsPipChannel.isPinned;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // PiP 切换按钮
            TVFocusable(
              onSelect: () async {
                await WindowsPipChannel.togglePipMode();
                // 延迟同步全屏状态，等待窗口状态稳定
                if (PlatformDetector.isWindows) {
                  await Future.delayed(const Duration(milliseconds: 300));
                  _isFullScreen = await windowManager.isFullScreen();
                }
                setState(() {});
              },
              focusScale: 1.0,
              showFocusBorder: false,
              builder: (context, isFocused, child) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: isInPip ? AppTheme.getGradient(context) : null,
                    color: isInPip
                        ? null
                        : (isFocused
                            ? AppTheme.getPrimaryColor(context)
                            : const Color(0x33FFFFFF)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isFocused
                          ? AppTheme.getPrimaryColor(context)
                          : const Color(0x1AFFFFFF),
                      width: isFocused ? 2 : 1,
                    ),
                  ),
                  child: child,
                );
              },
              child: Icon(
                isInPip ? Icons.fullscreen : Icons.picture_in_picture_alt,
                color: Colors.white,
                size: 18,
              ),
            ),
            // 图钉按钮 - 仅在遥控模式显示
            if (isInPip) ...[
              const SizedBox(width: 8),
              TVFocusable(
                onSelect: () async {
                  await WindowsPipChannel.togglePin();
                  setState(() {});
                },
                focusScale: 1.0,
                showFocusBorder: false,
                builder: (context, isFocused, child) {
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: isPinned ? AppTheme.getGradient(context) : null,
                      color: isPinned
                          ? null
                          : (isFocused
                              ? AppTheme.getPrimaryColor(context)
                              : const Color(0x33FFFFFF)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isFocused
                            ? AppTheme.getPrimaryColor(context)
                            : const Color(0x1AFFFFFF),
                        width: isFocused ? 2 : 1,
                      ),
                    ),
                    child: child,
                  );
                },
                child: Icon(
                  isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildBottomControls() {
    return PlayerBottomControls(
      isFullScreen: _isFullScreen,
      onToggleEpg: () {
        setState(() {
          _showEpgPanel = !_showEpgPanel;
          if (_showEpgPanel) {
            _showControls = false;
          }
        });
      },
      onShowSourceIndicator: (provider) {
        _showSourceSwitchIndicator(provider);
      },
      onShowSettings: (context) {
        _showSettingsSheet(context);
      },
      onToggleCategory: () {
        setState(() {
          if (_showCategoryPanel) {
            // 如果已显示，则隐藏
            _showCategoryPanel = false;
            _selectedCategory = null;
          } else {
            // 如果没显示，则显示并定位到当前频道
            final playerProvider = context.read<PlayerProvider>();
            final channelProvider = context.read<ChannelProvider>();
            final currentChannel = playerProvider.currentChannel;

            _showCategoryPanel = true;
            // 如果有当前频道，自动选中其所属分类
            if (currentChannel != null && currentChannel.groupName != null) {
              _selectedCategory = currentChannel.groupName;

              // 延迟滚动到当前频道位置
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_selectedCategory != null) {
                  final channels = channelProvider
                      .getChannelsByGroup(_selectedCategory!);
                  final currentIndex = channels.indexWhere(
                      (ch) => ch.id == currentChannel.id);

                  if (currentIndex >= 0 &&
                      _channelScrollController.hasClients) {
                    // 计算滚动位置（每个频道项高 44 像素高）
                    const itemHeight = 44.0;
                    final scrollOffset = currentIndex * itemHeight;

                    _channelScrollController.animateTo(
                      scrollOffset,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                }
              });
            } else {
              _selectedCategory = null;
            }
          }
        });
      },
      onToggleFullScreen: () {
        _toggleFullScreen();
        Future.delayed(const Duration(milliseconds: 120), () {
          if (mounted) _playerFocusNode.requestFocus();
        });
      },
    );
  }

  // 切换全屏模式 (仅Windows)
  void _toggleFullScreen() {
    if (!PlatformDetector.isWindows) return;

    // 简单的防抖
    final now = DateTime.now();
    if (_lastFullScreenToggle != null &&
        now.difference(_lastFullScreenToggle!).inMilliseconds < 200) {
      return;
    }
    _lastFullScreenToggle = now;

    // 使用原生 Windows API 切换全屏
    final success = WindowsFullscreenNative.toggleFullScreen();

    if (success) {
      // 异步更新UI状态
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _isFullScreen = WindowsFullscreenNative.isFullScreen();
          });
          _playerFocusNode.requestFocus();
        }
      });
    } else {
      // 如果原生 API 失败，回退到 window_manager
      ServiceLocator.log
          .d('Native fullscreen failed, falling back to window_manager');
      windowManager
          .isFullScreen()
          .then((value) => windowManager.setFullScreen(!value));

      Future.microtask(() {
        if (mounted) {
          windowManager.isFullScreen().then((isFullScreen) {
            if (mounted) {
              setState(() {
                _isFullScreen = isFullScreen;
              });
              _playerFocusNode.requestFocus();
            }
          });
        }
      });
    }
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getSurfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer<PlayerProvider>(
          builder: (context, provider, _) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.of(context)?.playbackSettings ??
                        'Playback Settings',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Playback Speed
                  Text(
                    AppStrings.of(context)?.playbackSpeed ?? 'Playback Speed',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                      final isSelected = provider.playbackSpeed == speed;
                      return ChoiceChip(
                        label: Text('${speed}x'),
                        selected: isSelected,
                        onSelected: (_) => provider.setPlaybackSpeed(speed),
                        selectedColor: AppTheme.getPrimaryColor(context),
                        backgroundColor: AppTheme.cardColor,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textSecondary,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryPanel() {
    final channelProvider = context.read<ChannelProvider>();
    return ChannelPanel(
      groups: channelProvider.groups,
      selectedCategory: _selectedCategory,
      categoryScrollController: _categoryScrollController,
      channelScrollController: _channelScrollController,
      onCategorySelected: (name) => setState(() => _selectedCategory = name),
      onBack: () => setState(() => _selectedCategory = null),
      onClose: () => setState(() {
        _showCategoryPanel = false;
        _selectedCategory = null;
      }),
    );
  }
}
