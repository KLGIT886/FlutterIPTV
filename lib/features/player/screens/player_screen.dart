import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';
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
import '../../epg/providers/epg_provider.dart';
import '../../multi_screen/providers/multi_screen_provider.dart';
import '../../multi_screen/widgets/multi_screen_player.dart';
import '../../../core/services/service_locator.dart';

class PlayerScreen extends StatefulWidget {
  final String channelUrl;
  final String channelName;
  final String? channelLogo;
  final bool isMultiScreen; // 鏄惁寮哄埗杩涘叆鍒嗗睆妯″紡

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
  Timer? _dlnaSyncTimer; // DLNA 鐘舵€佸悓姝ュ畾鏃跺櫒锛圓ndroid TV 鍘熺敓鎾斁鍣ㄧ敤锛?
  Timer? _wakelockTimer; // 瀹氭湡鍒锋柊wakelock锛堟墜鏈虹鐢級
  bool _showControls = true;
  final FocusNode _playerFocusNode = FocusNode();
  bool _usingNativePlayer = false;
  bool _showCategoryPanel = false;
  String? _selectedCategory;
  final ScrollController _categoryScrollController = ScrollController();
  final ScrollController _channelScrollController = ScrollController();

  // 淇濆瓨 provider 寮曠敤锛岀敤浜?dispose 鏃堕噴鏀捐祫婧?
  PlayerProvider? _playerProvider;
  MultiScreenProvider? _multiScreenProvider;
  SettingsProvider? _settingsProvider;

  // 鏈湴鍒嗗睆妯″紡鐘舵€侊紙涓嶅奖鍝嶈缃級
  bool _localMultiScreenMode = false;

  // 淇濆瓨鍒嗗睆妯″紡鐘舵€侊紝鐢ㄤ簬 dispose 鏃跺垽鏂?
  bool _wasMultiScreenMode = false;

  // 鏍囪鏄惁宸茬粡淇濆瓨浜嗗垎灞忕姸鎬侊紙閬垮厤閲嶅淇濆瓨锛?
  bool _multiScreenStateSaved = false;

  // 鎵嬪娍鎺у埗鐩稿叧鍙橀噺
  double _gestureStartY = 0;
  double _initialVolume = 0;
  double _initialBrightness = 0;
  bool _showGestureIndicator = false;
  double _gestureValue = 0;

  // 鏈湴 loading 鐘舵€侊紝鐢ㄤ簬寮哄埗鍒锋柊
  bool _isLoading = true;

  // 閿欒宸叉樉绀烘爣璁帮紝闃叉閲嶅鏄剧ず
  bool _errorShown = false;
  Timer? _errorHideTimer; // 閿欒鎻愮ず鑷姩闅愯棌瀹氭椂鍣?

  // Windows 鍏ㄥ睆鐘舵€?
  bool _isFullScreen = false;
  DateTime? _lastFullScreenToggle; // 璁板綍涓婃鍒囨崲鏃堕棿
  bool _mouseOver = false;

  // 妫€鏌ユ槸鍚﹀浜庡垎灞忔ā寮忥紙浣跨敤鏈湴鐘舵€侊級
  bool _isMultiScreenMode() {
    return _localMultiScreenMode && PlatformDetector.isDesktop;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 淇濇寔灞忓箷甯镐寒
    _enableWakelock();
    // 寤惰繜鍒?didChangeDependencies 涔嬪悗鍐嶆鏌ユ挱鏀惧櫒
    // 鍥犱负闇€瑕佸厛鍒濆鍖?_localMultiScreenMode
  }

  Future<void> _enableWakelock() async {
    // 鎵嬫満绔娇鐢ㄥ師鐢熸柟娉曠‘淇濆睆骞曞父浜?
    if (PlatformDetector.isMobile) {
      try {
        await PlatformDetector.setKeepScreenOn(true);
      } catch (e) {
        ServiceLocator.log.d('PlayerScreen: Failed to set keep screen on: $e');
      }
    } else {
      // 鍏朵粬骞冲彴浣跨敤wakelock_plus
      try {
        // 娣诲姞鐭殏寤惰繜锛岀‘淇滷lutter寮曟搸瀹屽叏鍒濆鍖?
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
    // 淇濆瓨 provider 寮曠敤骞舵坊鍔犵洃鍚?
    if (_playerProvider == null) {
      _playerProvider = context.read<PlayerProvider>();
      _playerProvider!.addListener(_onProviderUpdate);
      _isLoading = _playerProvider!.isLoading;

      // 淇濆瓨 settings 鍜?multi-screen provider 寮曠敤锛堢敤浜?dispose 鏃朵繚瀛樼姸鎬侊級
      _settingsProvider = context.read<SettingsProvider>();
      _multiScreenProvider = context.read<MultiScreenProvider>();

      // 妫€鏌ユ槸鍚︽槸 DLNA 鎶曞睆妯″紡
      bool isDlnaMode = false;
      try {
        final dlnaProvider = context.read<DlnaProvider>();
        isDlnaMode = dlnaProvider.isActiveSession;
      } catch (_) {}

      // 鍒濆鍖栨湰鍦板垎灞忔ā寮忕姸鎬侊紙鏍规嵁璁剧疆鎴栦紶鍏ュ弬鏁帮級
      // 濡傛灉浼犲叆鐨?isMultiScreen=true锛屽己鍒惰繘鍏ュ垎灞忔ā寮?
      // DLNA 鎶曞睆妯″紡涓嬩笉杩涘叆鍒嗗睆
      _localMultiScreenMode = !isDlnaMode &&
          (widget.isMultiScreen || _settingsProvider!.enableMultiScreen) &&
          PlatformDetector.isDesktop;

      // 濡傛灉鏄垎灞忔ā寮忎笖鍒嗗睆娌℃湁姝ｅ湪鎾斁鐨勯閬擄紝璁剧疆闊抽噺澧炲己鍒板垎灞廝rovider
      // 濡傛灉鍒嗗睆宸茬粡鏈夐閬撳湪鎾斁锛堜粠棣栭〉缁х画鎾斁杩涘叆锛夛紝涓嶈瑕嗙洊闊抽噺璁剧疆
      if (_localMultiScreenMode && !_multiScreenProvider!.hasAnyChannel) {
        _multiScreenProvider!.setVolumeSettings(
            _playerProvider!.volume, _settingsProvider!.volumeBoost);
      }

      // 鐜板湪鍙互瀹夊叏鍦版鏌ュ拰鍚姩鎾斁鍣ㄤ簡
      _checkAndLaunchPlayer();
    }
    // 淇濆瓨鍒嗗睆妯″紡鐘舵€?
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

    // 妫€鏌ラ敊璇姸鎬?
    if (provider.hasError && !_errorShown) {
      _checkAndShowError();
    }

    // 鍙湁 DLNA 鎶曞睆浼氳瘽鏃舵墠鍚屾鎾斁鐘舵€?
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
      // DLNA provider 鍙兘涓嶅彲鐢紝蹇界暐閿欒
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    ServiceLocator.log.d('PlayerScreen: AppLifecycleState changed to $state');
  }

  Future<void> _checkAndLaunchPlayer() async {
    // 鍒嗗睆妯″紡涓嬩笉鍚姩PlayerProvider鎾斁锛岀敱MultiScreenProvider澶勭悊
    if (_isMultiScreenMode()) {
      // 鍒嗗睆妯″紡锛氶殣钘忕郴缁烾I锛屼絾涓嶅惎鍔≒layerProvider
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

        // 妫€鏌ユ槸鍚︽槸 DLNA 鎶曞睆妯″紡
        bool isDlnaMode = false;
        try {
          final dlnaProvider = context.read<DlnaProvider>();
          isDlnaMode = dlnaProvider.isActiveSession;
          ServiceLocator.log
              .d('PlayerScreen: DLNA isActiveSession=$isDlnaMode');
        } catch (e) {
          ServiceLocator.log.d('PlayerScreen: Failed to get DlnaProvider: $e');
        }

        // 鑾峰彇棰戦亾鍒楄〃
        final channelProvider = context.read<ChannelProvider>();
        // 鉁?浣跨敤鍏ㄩ儴棰戦亾鑰屼笉鏄垎椤垫樉绀虹殑棰戦亾
        final channels = channelProvider.allChannels;

        // 璁剧疆 providers 鐢ㄤ簬鏀惰棌鍔熻兘鍜岀姸鎬佷繚瀛?
        final favoritesProvider = context.read<FavoritesProvider>();
        final settingsProvider = context.read<SettingsProvider>();
        NativePlayerChannel.setProviders(
            favoritesProvider, channelProvider, settingsProvider);

        // DLNA 妯″紡涓嬩笉浣跨敤棰戦亾鍒楄〃锛岀洿鎺ユ挱鏀句紶鍏ョ殑 URL
        List<String> urls;
        List<String> names;
        List<String> groups;
        List<List<String>> sources;
        List<String> logos;
        List<String> epgIds;
        List<bool> isSeekableList;
        int currentIndex = 0;

        if (isDlnaMode) {
          // DLNA 妯″紡锛氬彧鎾斁浼犲叆鐨刄RL锛屼笉鎻愪緵棰戦亾鍒囨崲鍔熻兘
          urls = [widget.channelUrl];
          names = [widget.channelName];
          groups = ['DLNA'];
          sources = [
            [widget.channelUrl]
          ];
          logos = [''];
          epgIds = [''];
          isSeekableList = [true]; // DLNA 鎶曞睆榛樿鍙嫋鍔?
          currentIndex = 0;
        } else {
          // 姝ｅ父妯″紡锛氫娇鐢ㄩ閬撳垪琛?
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

        // TV绔師鐢熸挱鏀惧櫒涔熼渶瑕佽褰曡鐪嬪巻鍙?
        if (!isDlnaMode && currentIndex >= 0 && currentIndex < channels.length) {
          final channel = channels[currentIndex];
          if (channel.id != null && channel.playlistId != null) {
            await ServiceLocator.watchHistory.addWatchHistory(channel.id!, channel.playlistId!);
            ServiceLocator.log.d('PlayerScreen: Recorded watch history for channel ${channel.name}');
          }
        }

        // 鑾峰彇缂撳啿寮哄害璁剧疆鍜屾樉绀鸿缃?
        final bufferStrength = settingsProvider.bufferStrength;
        final showFps = settingsProvider.showFps;
        final showClock = settingsProvider.showClock;
        final showNetworkSpeed = settingsProvider.showNetworkSpeed;
        final showVideoInfo = settingsProvider.showVideoInfo;

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
          progressBarMode: settingsProvider.progressBarMode, // 浼犻€掕繘搴︽潯鏄剧ず妯″紡
          showChannelName:
              settingsProvider.showMultiScreenChannelName, // 浼犻€掑灞忛閬撳悕绉版樉绀鸿缃?
          onClosed: () {
            ServiceLocator.log.d('PlayerScreen: Native player closed callback');
            // 鍋滄 DLNA 鍚屾瀹氭椂鍣?
            _dlnaSyncTimer?.cancel();
            _dlnaSyncTimer = null;

            // 閫氱煡 DLNA 鎾斁宸插仠姝紙濡傛灉鏄?DLNA 鎶曞睆鐨勮瘽锛?
            try {
              final dlnaProvider = context.read<DlnaProvider>();
              if (dlnaProvider.isActiveSession) {
                dlnaProvider.notifyPlaybackStopped();
              }
            } catch (e) {
              // 蹇界暐閿欒
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

          // 濡傛灉鏄?DLNA 鎶曞睆锛屽惎鍔ㄧ姸鎬佸悓姝ュ畾鏃跺櫒
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

    // 鎵嬫満绔畾鏈熷埛鏂皐akelock锛岄槻姝㈡煇浜涜澶囦笂wakelock澶辨晥
    if (PlatformDetector.isMobile) {
      _wakelockTimer?.cancel();
      _wakelockTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
        if (mounted) {
          await _enableWakelock();
        }
      });
    }

    // 涓嶅啀浣跨敤鎸佺画鐩戝惉锛屾敼涓轰竴娆℃€ч敊璇鏌?
  }

  /// 涓?Android TV 鍘熺敓鎾斁鍣ㄥ惎鍔?DLNA 鐘舵€佸悓姝?
  void _startDlnaSyncForNativePlayer() {
    try {
      final dlnaProvider = context.read<DlnaProvider>();
      // 娉ㄦ剰锛氫笉妫€鏌?isActiveSession锛屽洜涓哄湪 TV 绔帴鏀?DLNA 鎶曞睆鏃讹紝
      // 杩欎釜鏂规硶鍙兘鍦?isActiveSession 璁剧疆涔嬪墠灏辫璋冪敤浜?
      // 鍙 DLNA 鏈嶅姟鍦ㄨ繍琛岋紝灏卞惎鍔ㄥ悓姝ュ畾鏃跺櫒
      if (!dlnaProvider.isRunning) {
        ServiceLocator.log
            .d('PlayerScreen: DLNA service not running, skip sync timer');
        return;
      }

      ServiceLocator.log
          .d('PlayerScreen: Starting DLNA sync timer for native player');

      // 姣忕鍚屾涓€娆℃挱鏀剧姸鎬?
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

      // 鍏堝彇娑堜箣鍓嶇殑瀹氭椂鍣?
      _errorHideTimer?.cancel();

      // 娓呴櫎涔嬪墠鐨?SnackBar
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
        duration: const Duration(days: 365), // 璁剧疆寰堥暱鐨勬椂闂达紝鎵嬪姩鎺у埗闅愯棌
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

      // 3绉掑悗鎵嬪姩闅愯棌
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
    _errorShown = false; // 閲嶇疆閿欒鏄剧ず鏍囪
    _errorHideTimer?.cancel(); // 鍙栨秷閿欒闅愯棌瀹氭椂鍣?
    // 闅愯棌閿欒鎻愮ず
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }

    final playerProvider = context.read<PlayerProvider>();
    final channelProvider = context.read<ChannelProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    try {
      // Try to find the matching channel to enable playlist navigation
      final channel = channelProvider.channels.firstWhere(
        (c) => c.url == widget.channelUrl,
      );

      // 淇濆瓨涓婃鎾斁鐨勯閬揑D
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

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond >= 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else if (bytesPerSecond >= 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
    } else {
      return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    ServiceLocator.log.d(
        'PlayerScreen: dispose() called, _usingNativePlayer=$_usingNativePlayer, _wasMultiScreenMode=$_wasMultiScreenMode');

    // 棣栧厛绉婚櫎 provider 鐩戝惉鍣紝闃叉鍚庣画鏇存柊瑙﹀彂閿欒鏄剧ず
    if (_playerProvider != null) {
      _playerProvider!.removeListener(_onProviderUpdate);
    }

    // 鐒跺悗娓呴櫎鎵€鏈夐敊璇彁绀哄拰瀹氭椂鍣?
    _errorHideTimer?.cancel();
    _errorShown = false;

    // 绔嬪嵆娓呴櫎鎵€鏈?SnackBar锛堝寘鎷敊璇彁绀猴級
    try {
      ScaffoldMessenger.of(context).clearSnackBars();
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

    // 濡傛灉鏄?Windows mini 妯″紡锛岄€€鍑?mini 妯″紡
    if (WindowsPipChannel.isInPipMode) {
      WindowsPipChannel.exitPipMode();
    }

    // 濡傛灉鏄叏灞忔ā寮忥紝閫€鍑哄叏灞?- 浣跨敤鍘熺敓 API
    if (_isFullScreen && PlatformDetector.isWindows) {
      final success = WindowsFullscreenNative.exitFullScreen();
      if (!success) {
        ServiceLocator.log
            .d('Native exitFullScreen failed in dispose, using window_manager');
        unawaited(windowManager.setFullScreen(false));
      }
    }

    // 淇濆瓨鍒嗗睆鐘舵€侊紙Windows 骞冲彴)
    if (_wasMultiScreenMode && PlatformDetector.isDesktop) {
      _saveMultiScreenState();
    }

    // 绂诲紑鎾斁椤甸潰鏃讹紝鍗曞睆鍜屽灞忛兘蹇呴』鍋滄骞堕噴鏀?
    if (!_usingNativePlayer && _playerProvider != null) {
      ServiceLocator.log
          .d('PlayerScreen: calling _playerProvider.stop() in silent mode');
      unawaited(_playerProvider!.stop(silent: true));
    }
    if (PlatformDetector.isDesktop && _multiScreenProvider != null) {
      ServiceLocator.log
          .d('PlayerScreen: calling _multiScreenProvider.clearAllScreens() in dispose');
      unawaited(_multiScreenProvider!.clearAllScreens());
    }

    // 閲嶇疆浜害鍒扮郴缁熼粯璁?
    try {
      ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {}

    // 鍏抽棴灞忓箷甯镐寒
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

    super.dispose();
  }

  /// 淇濆瓨鍒嗗睆鐘舵€侊紙Windows 骞冲彴锛?
  void _saveMultiScreenState() {
    // 閬垮厤閲嶅淇濆瓨
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

      // 鑾峰彇姣忎釜灞忓箷鐨勯閬揑D
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

      // 淇濆瓨鍒嗗睆鐘舵€?
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

  /// 鏄剧ず婧愬垏鎹㈡寚绀哄櫒 (宸茬Щ闄わ紝鍥犱负椤堕儴宸叉湁鏄剧ず)
  void _showSourceSwitchIndicator(PlayerProvider provider) {
    // 涓嶅啀鏄剧ず SnackBar锛岄《閮ㄥ凡鏈夋簮鎸囩ず鍣?
  }

  void _saveLastChannelId(Channel? channel) {
    if (channel == null || channel.id == null) return;
    if (_settingsProvider != null && _settingsProvider!.rememberLastChannel) {
      // 淇濆瓨鍗曢閬撴挱鏀剧姸鎬?
      _settingsProvider!.saveLastSingleChannel(channel.id);
    }
  }

  // ============ 鎵嬫満绔墜鍔挎帶鍒?============

  // 绠€鍖栨墜鍔挎帶鍒?
  Offset? _panStartPosition;
  String?
      _currentGestureType; // 'volume', 'brightness', 'channel', 'horizontal'

  void _onPanStart(DragStartDetails details) {
    _panStartPosition = details.globalPosition;
    _currentGestureType = null;

    final playerProvider = _playerProvider ?? context.read<PlayerProvider>();
    _initialVolume = playerProvider.volume;
    _gestureStartY = details.globalPosition.dy;

    // 寮傛鑾峰彇褰撳墠浜害
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

    // 棣栨绉诲姩瓒呰繃闃堝€兼椂鍐冲畾鎵嬪娍绫诲瀷
    if (_currentGestureType == null) {
      const threshold = 10.0; // 闄嶄綆闃堝€硷紝鏇寸伒鏁?
      if (dx.abs() > threshold || dy.abs() > threshold) {
        final screenWidth = MediaQuery.of(context).size.width;
        final x = _panStartPosition!.dx;

        if (dy.abs() > dx.abs()) {
          // 鍨傜洿婊戝姩
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
          // 姘村钩婊戝姩
          _currentGestureType = 'horizontal';
        }
      }
      return;
    }

    // 澶勭悊鍨傜洿婊戝姩
    final screenHeight = MediaQuery.of(context).size.height;
    final deltaY = _gestureStartY - details.globalPosition.dy;

    if (_currentGestureType == 'volume') {
      final volumeChange =
          (deltaY / (screenHeight * 0.5)) * 1.0; // 婊戝姩鍗婂睆鏀瑰彉100%闊抽噺
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
      // 涓棿鍖哄煙鏄剧ず婊戝姩鎸囩ず
      setState(() {
        _showGestureIndicator = true;
        _gestureValue = dy.clamp(-100.0, 100.0) / 100.0; // 鐢ㄤ簬鏄剧ず鏂瑰悜
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

    // 澶勭悊棰戦亾鍒囨崲
    if (_currentGestureType == 'channel') {
      final threshold = screenHeight * 0.08; // 婊戝姩瓒呰繃灞忓箷8%鍗冲彲鍒囨崲
      if (dy.abs() > threshold) {
        _errorShown = false; // 鍒囨崲棰戦亾鏃堕噸缃敊璇爣璁?
        _errorHideTimer?.cancel(); // 鍙栨秷閿欒闅愯棌瀹氭椂鍣?
        // 闅愯棌閿欒鎻愮ず
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        final playerProvider =
            _playerProvider ?? context.read<PlayerProvider>();
        final channelProvider = context.read<ChannelProvider>();
        if (dy > 0) {
          // 涓嬫粦 -> 涓婁竴涓閬?
          playerProvider.playPrevious(channelProvider.filteredChannels);
          _saveLastChannelId(playerProvider.currentChannel);
        } else {
          // 涓婃粦 -> 涓嬩竴涓閬?
          playerProvider.playNext(channelProvider.filteredChannels);
          _saveLastChannelId(playerProvider.currentChannel);
        }
        // 寮哄埗鍒锋柊 UI
        setState(() {});
      }
    }

    // 澶勭悊姘村钩婊戝姩 - 鏄剧ず/闅愯棌鍒嗙被鑿滃崟
    if (_currentGestureType == 'horizontal') {
      final threshold = screenWidth * 0.15; // 婊戝姩瓒呰繃灞忓箷15%
      if (dx < -threshold && !_showCategoryPanel) {
        // 宸︽粦鏄剧ず鍒嗙被鑿滃崟
        setState(() {
          _showCategoryPanel = true;
          _showControls = false;
        });
      } else if (dx > threshold && _showCategoryPanel) {
        // 鍙虫粦鍏抽棴鍒嗙被鑿滃崟
        setState(() {
          _showCategoryPanel = false;
          _selectedCategory = null;
        });
      }
    }

    _resetGestureState();
  }

  void _resetGestureState() {
    setState(() {
      _showGestureIndicator = false;
    });
    _panStartPosition = null;
    _currentGestureType = null;
  }

  Widget _buildGestureIndicator() {
    IconData icon;
    String label;

    if (_currentGestureType == 'volume') {
      icon = _gestureValue > 0.5
          ? Icons.volume_up
          : (_gestureValue > 0 ? Icons.volume_down : Icons.volume_off);
      label = '${(_gestureValue * 100).toInt()}%';
    } else if (_currentGestureType == 'brightness') {
      icon = _gestureValue > 0.5 ? Icons.brightness_high : Icons.brightness_low;
      label = '${(_gestureValue * 100).toInt()}%';
    } else if (_currentGestureType == 'channel') {
      // 棰戦亾鍒囨崲鎸囩ず
      if (_gestureValue < 0) {
        icon = Icons.keyboard_arrow_up;
        label = AppStrings.of(context)?.nextChannel ?? 'Next channel';
      } else {
        icon = Icons.keyboard_arrow_down;
        label = AppStrings.of(context)?.previousChannel ?? 'Previous channel';
      }
    } else {
      return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(180),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 36),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _lastSelectKeyDownTime;
  DateTime? _lastLeftKeyDownTime; // 鐢ㄤ簬妫€娴嬮暱鎸夊乏閿?
  Timer? _longPressTimer; // 闀挎寜瀹氭椂鍣?

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

    // Left key - 鍒囨崲涓婁竴涓簮 / 闀挎寜鎵撳紑鍒嗙被闈㈡澘
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (event is KeyDownEvent) {
        if (event is KeyRepeatEvent) return KeyEventResult.handled;
        _lastLeftKeyDownTime = DateTime.now();
        // 鍚姩闀挎寜瀹氭椂鍣?
        _longPressTimer?.cancel();
        _longPressTimer = Timer(const Duration(milliseconds: 500), () {
          if (mounted && _lastLeftKeyDownTime != null) {
            // 闀挎寜锛氭墦寮€鍒嗙被闈㈡澘骞跺畾浣嶅埌褰撳墠棰戦亾
            final playerProvider = context.read<PlayerProvider>();
            final channelProvider = context.read<ChannelProvider>();
            final currentChannel = playerProvider.currentChannel;
            
            setState(() {
              _showCategoryPanel = true;
              // 濡傛灉鏈夊綋鍓嶉閬擄紝鑷姩閫変腑鍏舵墍灞炲垎绫?
              if (currentChannel != null && currentChannel.groupName != null) {
                _selectedCategory = currentChannel.groupName;
                
                // 寤惰繜婊氬姩鍒板綋鍓嶉閬撲綅缃?
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_selectedCategory != null) {
                    final channels = channelProvider.getChannelsByGroup(_selectedCategory!);
                    final currentIndex = channels.indexWhere((ch) => ch.id == currentChannel.id);
                    
                    if (currentIndex >= 0 && _channelScrollController.hasClients) {
                      // 璁＄畻婊氬姩浣嶇疆锛堟瘡涓閬撻」绾?44 鍍忕礌楂橈級
                      final itemHeight = 44.0;
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
            _lastLeftKeyDownTime = null; // 鏍囪宸插鐞嗛暱鎸?
          }
        });
        return KeyEventResult.handled;
      }

      if (event is KeyUpEvent) {
        _longPressTimer?.cancel();
        if (_lastLeftKeyDownTime != null) {
          // 鐭寜锛氬垏鎹笂涓€涓簮鎴栧叧闂垎绫婚潰鏉?
          _lastLeftKeyDownTime = null;

          if (_showCategoryPanel) {
            // 濡傛灉鍒嗙被闈㈡澘宸叉樉绀轰笖鍦ㄩ閬撳垪琛紝杩斿洖鍒嗙被鍒楄〃
            if (_selectedCategory != null) {
              setState(() => _selectedCategory = null);
              return KeyEventResult.handled;
            }
            // 濡傛灉鍦ㄥ垎绫诲垪琛紝鍏抽棴闈㈡澘
            setState(() {
              _showCategoryPanel = false;
              _selectedCategory = null;
            });
            return KeyEventResult.handled;
          }

          // 鍒囨崲鍒颁笂涓€涓簮
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

    // Right key - 鍒囨崲涓嬩竴涓簮
    if (key == LogicalKeyboardKey.arrowRight) {
      if (_showCategoryPanel) {
        // 濡傛灉鍦ㄥ垎绫婚潰鏉匡紝鍙抽敭涓嶅仛浠讳綍浜?
        return KeyEventResult.handled;
      }

      if (event is KeyDownEvent && event is! KeyRepeatEvent) {
        // 鍒囨崲鍒颁笅涓€涓簮
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
      _errorShown = false; // 鍒囨崲棰戦亾鏃堕噸缃敊璇爣璁?
      _errorHideTimer?.cancel(); // 鍙栨秷閿欒闅愯棌瀹氭椂鍣?
      // 闅愯棌閿欒鎻愮ず
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final channelProvider = context.read<ChannelProvider>();
      playerProvider.playPrevious(channelProvider.filteredChannels);
      // 淇濆瓨涓婃鎾斁鐨勯閬揑D
      _saveLastChannelId(playerProvider.currentChannel);
      return KeyEventResult.handled;
    }

    // Next Channel (Down)
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.channelDown) {
      _errorShown = false; // 鍒囨崲棰戦亾鏃堕噸缃敊璇爣璁?
      _errorHideTimer?.cancel(); // 鍙栨秷閿欒闅愯棌瀹氭椂鍣?
      // 闅愯棌閿欒鎻愮ず
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final channelProvider = context.read<ChannelProvider>();
      playerProvider.playNext(channelProvider.filteredChannels);
      // 淇濆瓨涓婃鎾斁鐨勯閬揑D
      _saveLastChannelId(playerProvider.currentChannel);
      return KeyEventResult.handled;
    }

    // Back/Exit
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      // 杩蜂綘妯″紡涓嬪厛閫€鍑鸿糠浣犳ā寮?
      if (WindowsPipChannel.isInPipMode) {
        WindowsPipChannel.exitPipMode();
        setState(() {});
        // 鎭㈠鐒︾偣鍒版挱鏀惧櫒
        _playerFocusNode.requestFocus();
        return KeyEventResult.handled;
      }

      // 鍏堟竻闄ゆ墍鏈夐敊璇彁绀哄拰鐘舵€?
      _errorHideTimer?.cancel();
      _errorShown = false;
      ScaffoldMessenger.of(context).clearSnackBars();

      // 涓嶉渶瑕佹墜鍔ㄨ皟鐢?stop()锛宒ispose 浼氳嚜鍔ㄥ鐞?
      // 鐩存帴杩斿洖鍗冲彲锛宒ispose 浼氬湪椤甸潰閿€姣佹椂璋冪敤

      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      return KeyEventResult.handled;
    }

    // Mute - 鍙湪TV绔鐞?
    if (key == LogicalKeyboardKey.keyM ||
        (key == LogicalKeyboardKey.audioVolumeMute &&
            !PlatformDetector.isMobile)) {
      playerProvider.toggleMute();
      return KeyEventResult.handled;
    }

    // Explicit Volume Keys (for TV remotes with dedicated buttons)
    // 鎵嬫満绔绯荤粺澶勭悊闊抽噺閿?
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

      // 鍏堟竻闄ゆ墍鏈夐敊璇彁绀哄拰鐘舵€?
      ServiceLocator.log.d('PlayerScreen: Clearing error state');
      _errorHideTimer?.cancel();
      _errorShown = false;
      ScaffoldMessenger.of(context).clearSnackBars();
      ServiceLocator.log.d('PlayerScreen: SnackBars cleared');

      // 涓嶉渶瑕佹墜鍔ㄨ皟鐢?stop()锛宒ispose 浼氳嚜鍔ㄥ鐞?
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
          // 椤甸潰宸茬粡 pop锛岀珛鍗虫竻闄ら敊璇彁绀?
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
              // 浣跨敤 translucent 璁╁瓙缁勪欢涔熻兘鎺ユ敹鐐瑰嚮浜嬩欢
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (_showCategoryPanel) {
                  setState(() {
                    _showCategoryPanel = false;
                    _selectedCategory = null;
                  });
                } else {
                  _showControlsTemporarily();
                }
              },
              onDoubleTap: () {
                context.read<PlayerProvider>().togglePlayPause();
              },
              // 鎵嬫満绔墜鍔挎帶鍒?- 浣跨敤 Pan 鎵嬪娍缁熶竴澶勭悊
              onPanStart: PlatformDetector.isMobile ? _onPanStart : null,
              onPanUpdate: PlatformDetector.isMobile ? _onPanUpdate : null,
              onPanEnd: PlatformDetector.isMobile ? _onPanEnd : null,
              child: Stack(
                children: [
                  // 鍏ㄥ睆鑳屾櫙锛岀‘淇濇墜鍔垮彲浠ュ湪鏁翠釜灞忓箷鍝嶅簲
                  const Positioned.fill(
                    child: ColoredBox(color: Colors.transparent),
                  ),

                  // Video Player
                  _buildVideoPlayer(),

                  // Controls Overlay - 鍒嗗睆妯″紡涓嬩笉鏄剧ず鍏ㄥ眬鎺у埗鏍?
                  if (!_isMultiScreenMode())
                    AnimatedOpacity(
                      opacity: _showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: IgnorePointer(
                        ignoring: !_showControls,
                        child: WindowsPipChannel.isInPipMode
                            ? _buildMiniControlsOverlay()
                            : _buildControlsOverlay(),
                      ),
                    ),

                  // Category Panel (Left side) - 杩蜂綘妯″紡鍜屽垎灞忔ā寮忎笅涓嶆樉绀?
                  if (_showCategoryPanel &&
                      !WindowsPipChannel.isInPipMode &&
                      !_isMultiScreenMode())
                    _buildCategoryPanel(),

                  // 鎵嬪娍鎸囩ず鍣?鎵嬫満绔?
                  if (_showGestureIndicator) _buildGestureIndicator(),

                  // Loading Indicator - 鍒嗗睆妯″紡涓嬩笉鏄剧ず鍏ㄥ眬鍔犺浇鎸囩ず鍣?
                  if (_isLoading && !_isMultiScreenMode())
                    Center(
                      child: Transform.scale(
                        scale: WindowsPipChannel.isInPipMode ? 0.6 : 1.0,
                        child: CircularProgressIndicator(
                          color: AppTheme.getPrimaryColor(context),
                        ),
                      ),
                    ),

                  // FPS 鏄剧ず - 鍙充笂瑙掔孩鑹诧紙杩蜂綘妯″紡鍗曠嫭鏄剧ず锛?
                  Builder(
                    builder: (context) {
                      final settings = context.watch<SettingsProvider>();
                      final player = context.watch<PlayerProvider>();

                      // 闈炶糠浣犳ā寮忎笅鐢变笅闈㈢殑缁勪欢缁熶竴鏄剧ず
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

                  // Windows 鎾斁鍣ㄤ俊鎭樉绀?- 鍙充笂瑙掞紙缃戦€熴€佹椂闂淬€丗PS銆佸垎杈ㄧ巼锛?
                  // 鍒嗗睆妯″紡涓嬩笉鏄剧ず鍏ㄥ眬淇℃伅锛堟瘡涓垎灞忔湁鑷繁鐨勪俊鎭樉绀猴級
                  Builder(
                    builder: (context) {
                      final settings = context.watch<SettingsProvider>();
                      final player = context.watch<PlayerProvider>();

                      // 鍒嗗睆妯″紡銆佽糠浣犳ā寮忔垨闈炴挱鏀剧姸鎬佷笉鏄剧ず
                      if (_isMultiScreenMode() ||
                          WindowsPipChannel.isInPipMode ||
                          player.state != PlayerState.playing) {
                        return const SizedBox.shrink();
                      }

                      // 妫€鏌ユ槸鍚︽湁浠讳綍淇℃伅闇€瑕佹樉绀?
                      final showAny = settings.showNetworkSpeed ||
                          settings.showClock ||
                          settings.showFps ||
                          settings.showVideoInfo;
                      if (!showAny) return const SizedBox.shrink();

                      final fps = player.currentFps;

                      return Positioned(
                        top: MediaQuery.of(context).padding.top + 8,
                        right: 16,
                        child: IgnorePointer(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 缃戦€熸樉绀?- 缁胯壊 (浠?TV 绔樉绀猴紝Windows 绔笉鏄剧ず)
                              if (settings.showNetworkSpeed &&
                                  player.downloadSpeed > 0 &&
                                  PlatformDetector.isTV)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _formatSpeed(player.downloadSpeed),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              // 鏃堕棿鏄剧ず - 榛戣壊
                              if (settings.showClock)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: StreamBuilder(
                                    stream: Stream.periodic(
                                        const Duration(seconds: 1)),
                                    builder: (context, snapshot) {
                                      final now = DateTime.now();
                                      return Text(
                                        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              // FPS 鏄剧ず - 绾㈣壊
                              if (settings.showFps && fps > 0)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${fps.toStringAsFixed(0)} FPS',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              // 鍒嗚鲸鐜囨樉绀?- 钃濊壊
                              if (settings.showVideoInfo &&
                                  player.videoWidth > 0 &&
                                  player.videoHeight > 0)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${player.videoWidth}x${player.videoHeight}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
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

  Widget _buildVideoPlayer() {
    // 浣跨敤鏈湴鐘舵€佸垽鏂槸鍚︽樉绀哄垎灞忔ā寮?
    if (_isMultiScreenMode()) {
      return _buildMultiScreenPlayer();
    }

    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        // 缁熶竴浣跨敤 media_kit
        if (provider.videoController == null) {
          return const SizedBox.expand(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return Video(
          controller: provider.videoController!,
          controls: NoVideoControls,
        );
      },
    );
  }

  // 鍒嗗睆鎾斁鍣?
  Widget _buildMultiScreenPlayer() {
    return MultiScreenPlayer(
      onExitMultiScreen: () {
        // 閫€鍑哄垎灞忔ā寮忥紝浣跨敤娲诲姩灞忓箷鐨勯閬撳叏灞忔挱鏀撅紙涓嶄慨鏀硅缃級
        final multiScreenProvider = context.read<MultiScreenProvider>();
        final activeChannel = multiScreenProvider.activeChannel;

        // 鍒囧洖鍗曞睆鍓嶏細閲婃斁澶氬睆鎾斁鍣紝浣嗕繚鐣欐瘡灞忛閬撶姸鎬侊紝鏂逛究鍐嶆杩涘叆鎭㈠
        multiScreenProvider.pauseAllScreens();

        // 鍒囨崲鍒板父瑙勬ā寮?
        setState(() {
          _localMultiScreenMode = false;
        });

        if (activeChannel != null) {
          // 浣跨敤涓绘挱鏀惧櫒鎾斁娲诲姩棰戦亾
          unawaited(_resumeSingleFromMultiScreen(activeChannel));
        }
      },
      onBack: () async {
        // 鍏堜繚瀛樺垎灞忕姸鎬侊紝鍐嶆竻绌?
        _saveMultiScreenState();
        // 杩斿洖鏃舵竻绌烘墍鏈夊垎灞忥紙绛夊緟瀹屾垚锛?
        final multiScreenProvider = context.read<MultiScreenProvider>();
        await multiScreenProvider.clearAllScreens();
        if (mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  // 鍒囨崲鍒板垎灞忔ā寮?

  Future<void> _resumeSingleFromMultiScreen(Channel activeChannel) async {
    final playerProvider = context.read<PlayerProvider>();
    final channelProvider = context.read<ChannelProvider>();

    // Prefer channel object from ChannelProvider to keep original source list/count.
    final matchedChannel = channelProvider.allChannels.cast<Channel?>().firstWhere(
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
    await playerProvider.playChannel(
      resumeChannel,
      preserveCurrentSource: true,
    );
  }

  void _switchToMultiScreenMode() {
    if (!PlatformDetector.isDesktop) return;
    final playerProvider = context.read<PlayerProvider>();
    final multiScreenProvider = context.read<MultiScreenProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final currentChannel = playerProvider.currentChannel;

    // 鍒囨崲鍒板灞忓墠鍏堝仠姝㈠崟灞忔挱鏀?
    unawaited(playerProvider.stop(silent: true));

    // 璁剧疆闊抽噺澧炲己鍒板垎灞廝rovider
    multiScreenProvider.setVolumeSettings(
        playerProvider.volume, settingsProvider.volumeBoost);

    // 鍒囨崲鍒板垎灞忔ā寮?
    setState(() {
      _localMultiScreenMode = true;
    });

    // 濡傛灉鍒嗗睆鏈夎浣忕殑棰戦亾锛屾仮澶嶆挱鏀?
    if (multiScreenProvider.hasAnyChannel) {
      multiScreenProvider.resumeAllScreens();
      // 濡傛灉褰撳墠鏈夐閬擄紝鏇存柊娲诲姩灞忓箷涓哄綋鍓嶉閬擄紙淇濈暀婧愮储寮曪級
      if (currentChannel != null) {
        final activeIndex = multiScreenProvider.activeScreenIndex;
        multiScreenProvider.playChannelOnScreen(activeIndex, currentChannel);
      }
    } else if (currentChannel != null) {
      // 鍚﹀垯濡傛灉鏈夊綋鍓嶉閬擄紝鍦ㄩ粯璁や綅缃挱鏀?
      final defaultPosition = settingsProvider.defaultScreenPosition;
      multiScreenProvider.playChannelAtDefaultPosition(
          currentChannel, defaultPosition);
    }
  }

  // 杩蜂綘妯″紡涓嬬殑绠€鍖栨帶鍒?
  Widget _buildMiniControlsOverlay() {
    return GestureDetector(
      // 鏁翠釜鍖哄煙鍙嫋鍔?
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.5),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Column(
          children: [
            // 椤堕儴锛氬彧淇濈暀鎭㈠鍜屽叧闂寜閽紝涓嶆樉绀烘爣棰?
            Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 鎭㈠澶у皬鎸夐挳
                  GestureDetector(
                    onTap: () async {
                      await WindowsPipChannel.exitPipMode();
                      // 寤惰繜鍚屾鍏ㄥ睆鐘舵€侊紝绛夊緟绐楀彛鎭㈠瀹屾垚
                      if (PlatformDetector.isWindows) {
                        await Future.delayed(const Duration(milliseconds: 300));
                        _isFullScreen = await windowManager.isFullScreen();
                      }
                      setState(() {});
                      // 鎭㈠鐒︾偣鍒版挱鏀惧櫒
                      _playerFocusNode.requestFocus();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.fullscreen,
                          color: Colors.white, size: 14),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // 鍏抽棴鎸夐挳
                  GestureDetector(
                    onTap: () {
                      WindowsPipChannel.exitPipMode();
                      context.read<PlayerProvider>().stop();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // 搴曢儴锛氶潤闊?+ 鎾斁/鏆傚仠鎸夐挳
            Padding(
              padding: const EdgeInsets.all(8),
              child: Consumer<PlayerProvider>(
                builder: (context, provider, _) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 闈欓煶鎸夐挳
                      GestureDetector(
                        onTap: provider.toggleMute,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            provider.isMuted
                                ? Icons.volume_off
                                : Icons.volume_up,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 鎾斁/鏆傚仠鎸夐挳
                      GestureDetector(
                        onTap: provider.togglePlayPause,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            gradient: AppTheme.lotusGradient,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            provider.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

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
              _buildTopBar(),
              const Spacer(),
              _buildBottomControls(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      // 璋冩暣椤堕儴闂磋窛涓?30锛屼娇鎸夐挳鍚戜笂绉诲姩锛屽噺灏戜笌淇℃伅绐楀彛鐨勮窛绂伙紝鍚屾椂淇濇寔涓嶉噸鍙?
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 16),
      child: Row(
        children: [
          // Semi-transparent channel logo/back button
          TVFocusable(
            onSelect: () async {
              // 鍏堟竻闄ゆ墍鏈夐敊璇彁绀哄拰鐘舵€?
              _errorHideTimer?.cancel();
              _errorShown = false;
              ScaffoldMessenger.of(context).clearSnackBars();

              // 濡傛灉鏄叏灞忕姸鎬侊紝鍏堥€€鍑哄叏灞?- 浣跨敤鍘熺敓 API
              if (_isFullScreen && PlatformDetector.isWindows) {
                _isFullScreen = false;
                final success = WindowsFullscreenNative.exitFullScreen();
                if (!success) {
                  // 濡傛灉鍘熺敓 API 澶辫触锛屽洖閫€鍒?window_manager
                  unawaited(windowManager.setFullScreen(false));
                }
              }

              // 涓嶉渶瑕佹墜鍔ㄨ皟鐢?stop()锛宒ispose 浼氳嚜鍔ㄥ鐞?

              // 鏈€鍚庡鑸繑鍥?
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
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
            child: const Icon(Icons.arrow_back_rounded,
                color: Colors.white, size: 18),
          ),

          const SizedBox(width: 16),

          // Minimal channel info
          Expanded(
            child: Consumer<PlayerProvider>(
              builder: (context, provider, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      provider.currentChannel?.name ?? widget.channelName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Live indicator
                        if (provider.state == PlayerState.playing) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: AppTheme.getGradient(context),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle,
                                    color: Colors.white, size: 6),
                                SizedBox(width: 4),
                                Text('LIVE',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // Source indicator (if multiple sources)
                        if (provider.currentChannel != null &&
                            provider.currentChannel!.hasMultipleSources) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.getPrimaryColor(context)
                                  .withOpacity(0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.swap_horiz,
                                    color: Colors.white, size: 10),
                                const SizedBox(width: 4),
                                Text(
                                  '${AppStrings.of(context)?.source ?? 'Source'} ${provider.currentSourceIndex}/${provider.sourceCount}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // Video info
                        if (provider.videoInfo.isNotEmpty)
                          Text(
                            provider.videoInfo,
                            style: const TextStyle(
                                color: Color(0x99FFFFFF), fontSize: 11),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),

          // Favorite button - minimal style
          Consumer<FavoritesProvider>(
            builder: (context, favorites, _) {
              final playerProvider = context.read<PlayerProvider>();
              final currentChannel = playerProvider.currentChannel;
              final isFav = currentChannel != null &&
                  favorites.isFavorite(currentChannel.id ?? 0);

              return TVFocusable(
                onSelect: () async {
                  if (currentChannel != null) {
                    ServiceLocator.log.d(
                        'TV鎾斁鍣? 灏濊瘯鍒囨崲鏀惰棌鐘舵€?- 棰戦亾: ${currentChannel.name}, ID: ${currentChannel.id}');
                    final success =
                        await favorites.toggleFavorite(currentChannel);
                    ServiceLocator.log.d('TV鎾斁鍣? 鏀惰棌鍒囨崲${success ? "鎴愬姛" : "澶辫触"}');

                    if (success) {
                      final newIsFav =
                          favorites.isFavorite(currentChannel.id ?? 0);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            newIsFav ? '已添加到收藏' : '已从收藏中移除',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  } else {
                    ServiceLocator.log.d('TV播放器: 当前频道为空，无法切换收藏');
                  }
                },
                focusScale: 1.0,
                showFocusBorder: false,
                builder: (context, isFocused, child) {
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: isFav ? AppTheme.getGradient(context) : null,
                      color: isFav
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
                  isFav ? Icons.favorite : Icons.favorite_border_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              );
            },
          ),

          // PiP 杩蜂綘鎾斁鍣ㄦ寜閽?- 浠?Windows
          if (WindowsPipChannel.isSupported) ...[
            const SizedBox(width: 8),
            _buildPipButton(),
          ],

          // 鍒嗗睆妯″紡鎸夐挳 - 浠呮闈㈠钩鍙?
          if (PlatformDetector.isDesktop) ...[
            const SizedBox(width: 8),
            _buildMultiScreenButton(),
          ],
        ],
      ),
    );
  }

  // 鍒嗗睆妯″紡鍒囨崲鎸夐挳
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

  // PiP 杩蜂綘鎾斁鍣ㄦ寜閽?
  Widget _buildPipButton() {
    return StatefulBuilder(
      builder: (context, setState) {
        final isInPip = WindowsPipChannel.isInPipMode;
        final isPinned = WindowsPipChannel.isPinned;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // PiP 鍒囨崲鎸夐挳
            TVFocusable(
              onSelect: () async {
                await WindowsPipChannel.togglePipMode();
                // 寤惰繜鍚屾鍏ㄥ睆鐘舵€侊紝绛夊緟绐楀彛鐘舵€佺ǔ瀹?
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
            // 缃《鎸夐挳 - 浠呭湪杩蜂綘妯″紡涓嬫樉绀?
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
    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // EPG 褰撳墠鑺傜洰鍜屼笅涓€涓妭鐩?
              Consumer<EpgProvider>(
                builder: (context, epgProvider, _) {
                  final channel = provider.currentChannel;
                  final currentProgram = epgProvider.getCurrentProgram(
                      channel?.epgId, channel?.name);
                  final nextProgram =
                      epgProvider.getNextProgram(channel?.epgId, channel?.name);

                  if (currentProgram != null || nextProgram != null) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0x33000000),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (currentProgram != null)
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.getPrimaryColor(context),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                        AppStrings.of(context)?.nowPlaying ??
                                            'Now playing',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      currentProgram.title,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    (AppStrings.of(context)?.endsInMinutes ??
                                            'Ends in {minutes} min')
                                        .replaceFirst('{minutes}',
                                            '${currentProgram.remainingMinutes}'),
                                    style: const TextStyle(
                                        color: Color(0x99FFFFFF), fontSize: 11),
                                  ),
                                ],
                              ),
                            if (nextProgram != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppTheme.getPrimaryColor(context)
                                              .withOpacity(0.7),
                                          AppTheme.getSecondaryColor(context)
                                              .withOpacity(0.7),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                        AppStrings.of(context)?.upNext ??
                                            'Up next',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      nextProgram.title,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // Progress bar for seekable content (VOD, Replay) - EPG 淇℃伅涓嬫柟
              Consumer<SettingsProvider>(
                builder: (context, settings, _) {
                  if (!provider
                      .shouldShowProgressBar(settings.progressBarMode)) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        // 杩涘害鏉★紙鏇村皬鐨勯珮搴︼級
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2, // 鍑忓皬杞ㄩ亾楂樺害
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 5), // 鍑忓皬婊戝潡澶у皬
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 10), // 鍑忓皬瑙︽懜鍖哄煙
                            activeTrackColor: AppTheme.getPrimaryColor(context),
                            inactiveTrackColor: const Color(0x33FFFFFF),
                            thumbColor: Colors.white,
                            overlayColor: AppTheme.getPrimaryColor(context)
                                .withOpacity(0.3),
                          ),
                          child: Slider(
                            value: provider.position.inSeconds.toDouble().clamp(
                                0, provider.duration.inSeconds.toDouble()),
                            max: provider.duration.inSeconds
                                .toDouble()
                                .clamp(1, double.infinity),
                            onChanged: (value) {
                              provider.seek(Duration(seconds: value.toInt()));
                            },
                          ),
                        ),
                        // 鏃堕棿鏄剧ず锛堟洿灏忕殑瀛椾綋鍜岄棿璺濓級
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(provider.position),
                                style: const TextStyle(
                                    color: Color(0x99FFFFFF), fontSize: 10),
                              ),
                              Text(
                                _formatDuration(provider.duration),
                                style: const TextStyle(
                                    color: Color(0x99FFFFFF), fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Control buttons row (moved above progress bar)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Volume control
                  _buildVolumeControl(provider),

                  const SizedBox(width: 16),

                  // 鎵嬫満绔簮鍒囨崲鎸夐挳 - 涓婁竴涓簮
                  if (PlatformDetector.isMobile &&
                      provider.currentChannel != null &&
                      provider.currentChannel!.hasMultipleSources)
                    TVFocusable(
                      onSelect: () {
                        provider.switchToPreviousSource();
                        _showSourceSwitchIndicator(provider);
                      },
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
                      child: const Icon(Icons.skip_previous_rounded,
                          color: Colors.white, size: 18),
                    ),

                  if (PlatformDetector.isMobile &&
                      provider.currentChannel != null &&
                      provider.currentChannel!.hasMultipleSources)
                    const SizedBox(width: 8),

                  // Play/Pause - Lotus gradient button (smaller)
                  TVFocusable(
                    autofocus: true,
                    onSelect: provider.togglePlayPause,
                    focusScale: 1.0,
                    showFocusBorder: false,
                    builder: (context, isFocused, child) {
                      return Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: AppTheme.getGradient(context),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                isFocused ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.getPrimaryColor(context)
                                  .withAlpha(isFocused ? 100 : 50),
                              blurRadius: isFocused ? 16 : 8,
                              spreadRadius: isFocused ? 2 : 1,
                            ),
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: Icon(
                      provider.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),

                  // 鎵嬫満绔簮鍒囨崲鎸夐挳 - 涓嬩竴涓簮
                  if (PlatformDetector.isMobile &&
                      provider.currentChannel != null &&
                      provider.currentChannel!.hasMultipleSources)
                    const SizedBox(width: 8),

                  if (PlatformDetector.isMobile &&
                      provider.currentChannel != null &&
                      provider.currentChannel!.hasMultipleSources)
                    TVFocusable(
                      onSelect: () {
                        provider.switchToNextSource();
                        _showSourceSwitchIndicator(provider);
                      },
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
                      child: const Icon(Icons.skip_next_rounded,
                          color: Colors.white, size: 18),
                    ),

                  if (!PlatformDetector.isMobile &&
                      provider.currentChannel != null &&
                      provider.currentChannel!.hasMultipleSources) ...[
                    const SizedBox(width: 8),
                    TVFocusable(
                      onSelect: () {
                        provider.switchToNextSource();
                        _showSourceSwitchIndicator(provider);
                      },
                      focusScale: 1.0,
                      showFocusBorder: false,
                      builder: (context, isFocused, child) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
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
                      child: Text(
                        '${AppStrings.of(context)?.source ?? 'Source'} ${provider.currentSourceIndex}/${provider.sourceCount}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],

                  const SizedBox(width: 16),

                  // Settings button (smaller)
                  TVFocusable(
                    onSelect: () => _showSettingsSheet(context),
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
                    child: const Icon(Icons.settings_rounded,
                        color: Colors.white, size: 18),
                  ),

                  const SizedBox(width: 16),

                  // Category menu button
                  TVFocusable(
                    onSelect: () {
                      setState(() {
                        if (_showCategoryPanel) {
                          // 濡傛灉宸叉樉绀猴紝鍒欓殣钘?
                          _showCategoryPanel = false;
                          _selectedCategory = null;
                        } else {
                          // 濡傛灉鏈樉绀猴紝鍒欐樉绀哄苟瀹氫綅鍒板綋鍓嶉閬?
                          final playerProvider = context.read<PlayerProvider>();
                          final channelProvider = context.read<ChannelProvider>();
                          final currentChannel = playerProvider.currentChannel;
                          
                          _showCategoryPanel = true;
                          // 濡傛灉鏈夊綋鍓嶉閬擄紝鑷姩閫変腑鍏舵墍灞炲垎绫?
                          if (currentChannel != null && currentChannel.groupName != null) {
                            _selectedCategory = currentChannel.groupName;
                            
                            // 寤惰繜婊氬姩鍒板綋鍓嶉閬撲綅缃?
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_selectedCategory != null) {
                                final channels = channelProvider.getChannelsByGroup(_selectedCategory!);
                                final currentIndex = channels.indexWhere((ch) => ch.id == currentChannel.id);
                                
                                if (currentIndex >= 0 && _channelScrollController.hasClients) {
                                  // 璁＄畻婊氬姩浣嶇疆锛堟瘡涓閬撻」绾?44 鍍忕礌楂橈級
                                  final itemHeight = 44.0;
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
                    child: const Icon(Icons.menu_rounded,
                        color: Colors.white, size: 18),
                  ),

                  // Windows 鍏ㄥ睆鎸夐挳
                  if (PlatformDetector.isWindows) ...[
                    const SizedBox(width: 16),
                    TVFocusable(
                      onSelect: () {
                        _toggleFullScreen();
                        Future.delayed(const Duration(milliseconds: 120), () {
                          if (mounted) _playerFocusNode.requestFocus();
                        });
                      },
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
                      child: Icon(
                          _isFullScreen
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                          color: Colors.white,
                          size: 18),
                    ),
                  ],
                ],
              ),

              // Keyboard hints
              if (PlatformDetector.useDPadNavigation)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    AppStrings.of(context)?.playerHintTV ??
                        '鈫戔啌 鍒囨崲棰戦亾 路 鈫愨啋 鍒囨崲婧?路 闀挎寜鈫?鍒嗙被 路 OK 鎾斁/鏆傚仠 路 闀挎寜OK 鏀惰棌',
                    style:
                        const TextStyle(color: Color(0x66FFFFFF), fontSize: 11),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVolumeControl(PlayerProvider provider) {
    // 纭繚闊抽噺鍊煎湪 0-1 鑼冨洿鍐?
    final volume = provider.volume.clamp(0.0, 1.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TVFocusable(
          onSelect: provider.toggleMute,
          focusScale: 1.0,
          showFocusBorder: false,
          builder: (context, isFocused, child) {
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isFocused
                    ? AppTheme.getPrimaryColor(context)
                    : const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(8),
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
            provider.isMuted || volume == 0
                ? Icons.volume_off_rounded
                : volume < 0.5
                    ? Icons.volume_down_rounded
                    : Icons.volume_up_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 70,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
            ),
            child: Slider(
              value: provider.isMuted ? 0 : volume,
              onChanged: (value) {
                // 濡傛灉褰撳墠鏄潤闊崇姸鎬侊紝鎷栧姩婊戝潡鏃跺厛鍙栨秷闈欓煶
                if (provider.isMuted && value > 0) {
                  provider.toggleMute();
                }
                provider.setVolume(value);
              },
              activeColor: AppTheme.getPrimaryColor(context),
              inactiveColor: const Color(0x33FFFFFF),
            ),
          ),
        ),
      ],
    );
  }

  // 鍒囨崲鍏ㄥ睆妯″紡 (浠?Windows)
  void _toggleFullScreen() {
    if (!PlatformDetector.isWindows) return;

    // 绠€鍗曠殑闃叉姈
    final now = DateTime.now();
    if (_lastFullScreenToggle != null &&
        now.difference(_lastFullScreenToggle!).inMilliseconds < 200) {
      return;
    }
    _lastFullScreenToggle = now;

    // 浣跨敤鍘熺敓 Windows API 鍒囨崲鍏ㄥ睆
    final success = WindowsFullscreenNative.toggleFullScreen();

    if (success) {
      // 寮傛鏇存柊UI鐘舵€?
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _isFullScreen = WindowsFullscreenNative.isFullScreen();
          });
          _playerFocusNode.requestFocus();
        }
      });
    } else {
      // 濡傛灉鍘熺敓 API 澶辫触锛屽洖閫€鍒?window_manager
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
    final groups = channelProvider.groups;
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      child: Row(
        children: [
          // 鍒嗙被鍒楄〃
          Container(
            width: 180,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xE6000000),
                  Color(0x99000000),
                  Colors.transparent,
                ],
                stops: [0.0, 0.7, 1.0],
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      AppStrings.of(context)?.categories ?? 'Categories',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _categoryScrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        final isSelected = _selectedCategory == group.name;
                        return TVFocusable(
                          autofocus: index == 0 && _selectedCategory == null,
                          onSelect: () {
                            setState(() {
                              _selectedCategory = group.name;
                            });
                          },
                          focusScale: 1.0,
                          showFocusBorder: false,
                          builder: (context, isFocused, child) {
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: (isFocused || isSelected)
                                    ? AppTheme.getGradient(context)
                                    : null,
                                color: (isFocused || isSelected)
                                    ? null
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: child,
                            );
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  group.name,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${group.channelCount}',
                                style: const TextStyle(
                                    color: Color(0x99FFFFFF), fontSize: 11),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 棰戦亾鍒楄〃锛堝綋閫変腑鍒嗙被鏃舵樉绀猴級
          if (_selectedCategory != null) _buildChannelList(),
        ],
      ),
    );
  }

  Widget _buildChannelList() {
    final channelProvider = context.read<ChannelProvider>();
    final playerProvider = context.read<PlayerProvider>();
    final channels = channelProvider.getChannelsByGroup(_selectedCategory!);
    final currentChannel = playerProvider.currentChannel;

    return Container(
      width: 220,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xCC000000),
            Color(0x66000000),
            Colors.transparent,
          ],
          stops: [0.0, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _selectedCategory = null),
                    child: const Icon(Icons.arrow_back_ios,
                        color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedCategory!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _channelScrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: channels.length,
                itemBuilder: (context, index) {
                  final channel = channels[index];
                  final isPlaying = currentChannel?.id == channel.id;
                  return TVFocusable(
                    autofocus: isPlaying, // 褰撳墠鎾斁鐨勯閬撹嚜鍔ㄨ幏寰楃劍鐐?
                    onSelect: () {
                      // 淇濆瓨涓婃鎾斁鐨勯閬揑D
                      final settingsProvider = context.read<SettingsProvider>();
                      if (settingsProvider.rememberLastChannel &&
                          channel.id != null) {
                        settingsProvider.setLastChannelId(channel.id);
                      }

                      // 鍒囨崲鍒拌棰戦亾
                      playerProvider.playChannel(channel);
                      // 鍏抽棴闈㈡澘
                      setState(() {
                        _showCategoryPanel = false;
                        _selectedCategory = null;
                      });
                    },
                    focusScale: 1.0,
                    showFocusBorder: false,
                    builder: (context, isFocused, child) {
                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          gradient:
                              isFocused ? AppTheme.getGradient(context) : null,
                          color: isPlaying && !isFocused
                              ? const Color(0x33E91E63)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: child,
                      );
                    },
                    child: Row(
                      children: [
                        if (isPlaying)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(Icons.play_arrow,
                                color: AppTheme.getPrimaryColor(context),
                                size: 16),
                          ),
                        Expanded(
                          child: Text(
                            channel.name,
                            style: TextStyle(
                              color: isPlaying
                                  ? AppTheme.getPrimaryColor(context)
                                  : Colors.white,
                              fontSize: 13,
                              fontWeight: isPlaying
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

