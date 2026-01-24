import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:async';

import '../../../core/i18n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
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
import '../widgets/player_controls.dart';
import '../widgets/player_mini_controls.dart';
import '../widgets/player_category_panel.dart';
import '../widgets/player_info_display.dart';
import '../widgets/player_settings_sheet.dart';
import '../widgets/player_video_layer.dart';
import '../widgets/player_gesture_overlay.dart';

class PlayerScreen extends StatefulWidget {
  final String channelUrl;
  final String channelName;
  final String? channelLogo;
  final bool isMultiScreen;

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

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  Timer? _dlnaSyncTimer;
  Timer? _wakelockTimer;
  bool _showControls = true;
  final FocusNode _playerFocusNode = FocusNode();
  bool _usingNativePlayer = false;
  bool _showCategoryPanel = false;
  String? _selectedCategory;
  final ScrollController _categoryScrollController = ScrollController();
  final ScrollController _channelScrollController = ScrollController();

  PlayerProvider? _playerProvider;
  MultiScreenProvider? _multiScreenProvider;
  SettingsProvider? _settingsProvider;

  bool _localMultiScreenMode = false;
  bool _wasMultiScreenMode = false;
  bool _multiScreenStateSaved = false;
  bool _isLoading = true;
  bool _errorShown = false;
  bool _isFullScreen = false;
  DateTime? _lastFullScreenToggle;

  bool _isMultiScreenMode() => _localMultiScreenMode && PlatformDetector.isDesktop;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enableWakelock();
  }

  Future<void> _enableWakelock() async {
    if (PlatformDetector.isMobile) {
      await PlatformDetector.setKeepScreenOn(true);
    } else {
      try {
        await WakelockPlus.enable();
      } catch (e) {
        debugPrint('PlayerScreen: Failed to enable wakelock: $e');
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_playerProvider == null) {
      _playerProvider = context.read<PlayerProvider>();
      _playerProvider!.addListener(_onProviderUpdate);
      _isLoading = _playerProvider!.isLoading;
      _settingsProvider = context.read<SettingsProvider>();
      _multiScreenProvider = context.read<MultiScreenProvider>();

      bool isDlnaMode = false;
      try {
        isDlnaMode = context.read<DlnaProvider>().isActiveSession;
      } catch (_) {}

      _localMultiScreenMode = !isDlnaMode &&
          (widget.isMultiScreen || _settingsProvider!.enableMultiScreen) &&
          PlatformDetector.isDesktop;

      if (_localMultiScreenMode && !_multiScreenProvider!.hasAnyChannel) {
        _multiScreenProvider!.setVolumeSettings(_playerProvider!.volume, _settingsProvider!.volumeBoost);
      }
      _checkAndLaunchPlayer();
    }
    _wasMultiScreenMode = _isMultiScreenMode();
  }

  void _onProviderUpdate() {
    if (!mounted) return;
    final provider = _playerProvider;
    if (provider == null) return;

    final newLoading = provider.isLoading;
    if (_isLoading != newLoading) {
      setState(() => _isLoading = newLoading);
    }

    if (provider.hasError && !_errorShown) {
      _checkAndShowError();
    }

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
    } catch (_) {}
  }

  Future<void> _checkAndLaunchPlayer() async {
    if (_isMultiScreenMode()) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      return;
    }

    if (PlatformDetector.isTV && PlatformDetector.isAndroid) {
      final nativeAvailable = await NativePlayerChannel.isAvailable();
      if (nativeAvailable && mounted) {
        _usingNativePlayer = true;
        
        bool isDlnaMode = false;
        try {
          isDlnaMode = context.read<DlnaProvider>().isActiveSession;
        } catch (_) {}

        final channelProvider = context.read<ChannelProvider>();
        final favoritesProvider = context.read<FavoritesProvider>();
        final settingsProvider = context.read<SettingsProvider>();
        
        NativePlayerChannel.setProviders(favoritesProvider, channelProvider, settingsProvider);

        List<String> urls, names, groups, logos, epgIds;
        List<List<String>> sources;
        int currentIndex = 0;

        if (isDlnaMode) {
          urls = [widget.channelUrl];
          names = [widget.channelName];
          groups = ['DLNA'];
          sources = [[widget.channelUrl]];
          logos = [''];
          epgIds = [''];
        } else {
          final channels = channelProvider.channels;
          currentIndex = channels.indexWhere((c) => c.url == widget.channelUrl);
          if (currentIndex == -1) currentIndex = 0;
          urls = channels.map((c) => c.url).toList();
          names = channels.map((c) => c.name).toList();
          groups = channels.map((c) => c.groupName ?? '').toList();
          sources = channels.map((c) => c.sources).toList();
          logos = channels.map((c) => c.logoUrl ?? '').toList();
          epgIds = channels.map((c) => c.epgId ?? '').toList();
        }

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
          isDlnaMode: isDlnaMode,
          bufferStrength: settingsProvider.bufferStrength,
          showFps: settingsProvider.showFps,
          showClock: settingsProvider.showClock,
          showNetworkSpeed: settingsProvider.showNetworkSpeed,
          showVideoInfo: settingsProvider.showVideoInfo,
          onClosed: () {
            _dlnaSyncTimer?.cancel();
            try {
              final dlna = context.read<DlnaProvider>();
              if (dlna.isActiveSession) dlna.notifyPlaybackStopped();
            } catch (_) {}
            if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
          },
        );

        if (launched && mounted) {
          _startDlnaSyncForNativePlayer();
          return;
        } else if (mounted) {
          _usingNativePlayer = false;
          _initFlutterPlayer();
        }
        return;
      }
    }
    if (mounted) {
      _usingNativePlayer = false;
      _initFlutterPlayer();
    }
  }

  void _initFlutterPlayer() {
    _startPlayback();
    setState(() => _showControls = true);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (PlatformDetector.isMobile) {
      _wakelockTimer?.cancel();
      _wakelockTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
        if (mounted) await _enableWakelock();
      });
    }
  }

  void _startDlnaSyncForNativePlayer() {
    try {
      final dlnaProvider = context.read<DlnaProvider>();
      if (!dlnaProvider.isActiveSession) return;

      _dlnaSyncTimer?.cancel();
      _dlnaSyncTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        if (!mounted) {
          _dlnaSyncTimer?.cancel();
          return;
        }
        try {
          final state = await NativePlayerChannel.getPlaybackState();
          if (state != null) {
            dlnaProvider.syncPlayerState(
              isPlaying: (state['isPlaying'] as bool?) ?? false,
              isPaused: (state['state'] as String?) == 'paused',
              position: Duration(milliseconds: (state['position'] as int?) ?? 0),
              duration: Duration(milliseconds: (state['duration'] as int?) ?? 0),
            );

          }
        } catch (_) {}
      });
    } catch (_) {}
  }

  void _checkAndShowError() {
    if (!mounted || _errorShown) return;
    final provider = context.read<PlayerProvider>();
    if (provider.hasError && provider.error != null) {
      final errorMessage = provider.error!;
      _errorShown = true;
      provider.clearError();

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.of(context)?.playbackError ?? "Error"}: $errorMessage'),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 30),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: AppStrings.of(context)?.retry ?? 'Retry',
            textColor: Colors.white,
            onPressed: () {
              _errorShown = false;
              _startPlayback();
            },
          ),
        ),
      );
    }
  }

  void _startPlayback() {
    _errorShown = false;
    final playerProvider = context.read<PlayerProvider>();
    final channelProvider = context.read<ChannelProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    try {
      final channel = channelProvider.channels.firstWhere((c) => c.url == widget.channelUrl);
      if (settingsProvider.rememberLastChannel && channel.id != null) {
        settingsProvider.setLastChannelId(channel.id);
      }
      playerProvider.playChannel(channel);
    } catch (_) {
      playerProvider.playUrl(widget.channelUrl, name: widget.channelName);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dlnaSyncTimer?.cancel();
    _wakelockTimer?.cancel();
    _longPressTimer?.cancel();
    _playerFocusNode.dispose();
    _categoryScrollController.dispose();
    _channelScrollController.dispose();

    if (WindowsPipChannel.isInPipMode) WindowsPipChannel.exitPipMode();

    if (_isFullScreen && PlatformDetector.isWindows) {
      if (!WindowsFullscreenNative.exitFullScreen()) windowManager.setFullScreen(false);
    }
    
    if (_wasMultiScreenMode && PlatformDetector.isDesktop) _saveMultiScreenState();

    if (!_usingNativePlayer && _playerProvider != null && !_wasMultiScreenMode) {
      _playerProvider!.removeListener(_onProviderUpdate);
      _playerProvider!.stop();
    } else if (_playerProvider != null) {
      _playerProvider!.removeListener(_onProviderUpdate);
    }

    if (PlatformDetector.isMobile) {
      PlatformDetector.setKeepScreenOn(false);
    } else {
      WakelockPlus.disable();
    }

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _saveMultiScreenState() {
    if (_multiScreenStateSaved) return;
    try {
      if (_multiScreenProvider == null || _settingsProvider == null) return;
      final List<int?> channelIds = List.generate(4, (i) => _multiScreenProvider!.getScreen(i).channel?.id);
      _settingsProvider!.saveLastMultiScreen(channelIds, _multiScreenProvider!.activeScreenIndex);
      _multiScreenStateSaved = true;
    } catch (_) {}
  }

  void _saveLastChannelId(Channel? channel) {
    if (channel?.id != null && _settingsProvider?.rememberLastChannel == true) {
      _settingsProvider!.saveLastSingleChannel(channel!.id);
    }
  }

  DateTime? _lastSelectKeyDownTime;
  DateTime? _lastLeftKeyDownTime;
  Timer? _longPressTimer;

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    setState(() => _showControls = true);
    final playerProvider = context.read<PlayerProvider>();
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) {
        if (event is! KeyRepeatEvent) _lastSelectKeyDownTime = DateTime.now();
        return KeyEventResult.handled;
      }
      if (event is KeyUpEvent && _lastSelectKeyDownTime != null) {
        final duration = DateTime.now().difference(_lastSelectKeyDownTime!);
        _lastSelectKeyDownTime = null;
        if (duration.inMilliseconds > 500) {
          final favorites = context.read<FavoritesProvider>();
          final channel = playerProvider.currentChannel;
          if (channel != null) {
            favorites.toggleFavorite(channel);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(favorites.isFavorite(channel.id ?? 0) ? 'Added to Favorites' : 'Removed from Favorites'),
              duration: const Duration(seconds: 1),
              backgroundColor: AppTheme.accentColor,
            ));
          }
        } else {
          playerProvider.togglePlayPause();
        }
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (event is KeyDownEvent) {
        if (event is! KeyRepeatEvent) {
          _lastLeftKeyDownTime = DateTime.now();
          _longPressTimer?.cancel();
          _longPressTimer = Timer(const Duration(milliseconds: 500), () {
            if (mounted && _lastLeftKeyDownTime != null) {
              setState(() { _showCategoryPanel = true; _selectedCategory = null; });
              _lastLeftKeyDownTime = null;
            }
          });
        }
        return KeyEventResult.handled;
      }
      if (event is KeyUpEvent) {
        _longPressTimer?.cancel();
        if (_lastLeftKeyDownTime != null) {
          _lastLeftKeyDownTime = null;
          if (_showCategoryPanel) {
            if (_selectedCategory != null) {
              setState(() => _selectedCategory = null);
            } else {
              setState(() => _showCategoryPanel = false);
            }
          } else if (playerProvider.currentChannel?.hasMultipleSources == true) {
            playerProvider.switchToPreviousSource();
          }
        }
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      if (_showCategoryPanel) return KeyEventResult.handled;
      if (event is KeyDownEvent && event is! KeyRepeatEvent && playerProvider.currentChannel?.hasMultipleSources == true) {
        playerProvider.switchToNextSource();
      }
      return KeyEventResult.handled;
    }

    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.channelUp) {
      _errorShown = false;
      playerProvider.playPrevious(context.read<ChannelProvider>().filteredChannels);
      _saveLastChannelId(playerProvider.currentChannel);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.channelDown) {
      _errorShown = false;
      playerProvider.playNext(context.read<ChannelProvider>().filteredChannels);
      _saveLastChannelId(playerProvider.currentChannel);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      if (WindowsPipChannel.isInPipMode) {
        WindowsPipChannel.exitPipMode();
        setState(() {});
        _playerFocusNode.requestFocus();
      } else {
        playerProvider.stop();
        if (Navigator.canPop(context)) Navigator.of(context).pop();
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyM || (key == LogicalKeyboardKey.audioVolumeMute && !PlatformDetector.isMobile)) {
      playerProvider.toggleMute();
      return KeyEventResult.handled;
    }

    if (!PlatformDetector.isMobile) {
      if (key == LogicalKeyboardKey.audioVolumeUp) { playerProvider.setVolume(playerProvider.volume + 0.1); return KeyEventResult.handled; }
      if (key == LogicalKeyboardKey.audioVolumeDown) { playerProvider.setVolume(playerProvider.volume - 0.1); return KeyEventResult.handled; }
    }

    if (key == LogicalKeyboardKey.settings || key == LogicalKeyboardKey.contextMenu) {
      PlayerSettingsSheet.show(context);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.backspace) {
      playerProvider.stop();
      if (Navigator.canPop(context)) Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isMulti = _isMultiScreenMode();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _playerFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: PlayerGestureOverlay(
          showCategoryPanel: _showCategoryPanel,
          onShowControls: () => setState(() => _showControls = true),
          onHideControls: () => setState(() => _showControls = false),
          onToggleCategoryPanel: (v) => setState(() => _showCategoryPanel = v),
          onCategorySelected: (v) => setState(() => _selectedCategory = v),
          onTogglePlayPause: () => context.read<PlayerProvider>().togglePlayPause(),
          onPlayNext: () {
            _errorShown = false;
            final pp = context.read<PlayerProvider>();
            pp.playNext(context.read<ChannelProvider>().filteredChannels);
            _saveLastChannelId(pp.currentChannel);
          },
          onPlayPrevious: () {
            _errorShown = false;
            final pp = context.read<PlayerProvider>();
            pp.playPrevious(context.read<ChannelProvider>().filteredChannels);
            _saveLastChannelId(pp.currentChannel);
          },
          child: Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: Colors.transparent)),
              PlayerVideoLayer(
                isMultiScreenMode: isMulti,
                onExitMultiScreen: () {
                  final mp = context.read<MultiScreenProvider>();
                  final active = mp.activeChannel;
                  mp.pauseAllScreens();
                  setState(() => _localMultiScreenMode = false);
                  if (active != null) context.read<PlayerProvider>().playChannel(active);
                },
                onMultiScreenBack: () async {
                  _saveMultiScreenState();
                  await context.read<MultiScreenProvider>().clearAllScreens();
                  if (mounted) Navigator.of(context).pop();
                },
              ),

              if (!isMulti)
                AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: WindowsPipChannel.isInPipMode
                        ? PlayerMiniControls(
                            playerFocusNode: _playerFocusNode,
                            onFullScreenChanged: (v) => setState(() => _isFullScreen = v),
                          )
                        : PlayerControls(
                            channelName: widget.channelName,
                            isFullScreen: _isFullScreen,
                            onBackPressed: () {
                              if (_isFullScreen && PlatformDetector.isWindows) {
                                if (!WindowsFullscreenNative.exitFullScreen()) windowManager.setFullScreen(false);
                              }
                              context.read<PlayerProvider>().stop();
                              Navigator.of(context).pop();
                            },
                            onSettingsPressed: () => PlayerSettingsSheet.show(context),
                            onFullScreenToggle: _toggleFullScreen,
                            onMultiScreenToggle: _switchToMultiScreenMode,
                            onSourceSwitched: (provider) {
                              // 可以添加源切换的提示逻辑
                            },
                          ),

                  ),
                ),

              if (_showCategoryPanel && !WindowsPipChannel.isInPipMode && !isMulti)
                PlayerCategoryPanel(
                  categoryScrollController: _categoryScrollController,
                  channelScrollController: _channelScrollController,
                  initialSelectedCategory: _selectedCategory,
                  onClose: () => setState(() { _showCategoryPanel = false; _selectedCategory = null; }),
                ),

              if (_isLoading && !isMulti)
                Center(
                  child: Transform.scale(
                    scale: WindowsPipChannel.isInPipMode ? 0.6 : 1.0,
                    child: CircularProgressIndicator(color: AppTheme.getPrimaryColor(context)),
                  ),
                ),

              PlayerInfoDisplay(isMultiScreenMode: isMulti),
            ],
          ),
        ),
      ),
    );
  }

  void _switchToMultiScreenMode() {
    final pp = context.read<PlayerProvider>();
    final mp = context.read<MultiScreenProvider>();
    final sp = context.read<SettingsProvider>();
    final current = pp.currentChannel;

    pp.stop();
    mp.setVolumeSettings(pp.volume, sp.volumeBoost);
    setState(() => _localMultiScreenMode = true);

    if (mp.hasAnyChannel) {
      mp.resumeAllScreens();
      if (current != null) mp.playChannelOnScreen(mp.activeScreenIndex, current);
    } else if (current != null) {
      mp.playChannelAtDefaultPosition(current, sp.defaultScreenPosition);
    }
  }

  void _toggleFullScreen() {
    if (!PlatformDetector.isWindows) return;
    final now = DateTime.now();
    if (_lastFullScreenToggle != null && now.difference(_lastFullScreenToggle!).inMilliseconds < 200) return;
    _lastFullScreenToggle = now;

    if (WindowsFullscreenNative.toggleFullScreen()) {
      Future.microtask(() { if (mounted) setState(() => _isFullScreen = WindowsFullscreenNative.isFullScreen()); });
    } else {
      windowManager.isFullScreen().then((v) => windowManager.setFullScreen(!v));
      Future.microtask(() {
        if (mounted) windowManager.isFullScreen().then((isFS) { if (mounted) setState(() => _isFullScreen = isFS); });
      });
    }
  }
}
