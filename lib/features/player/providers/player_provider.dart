import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

import '../../../core/models/channel.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/channel_test_service.dart';
import '../../../core/services/log_service.dart';
import '../../settings/providers/settings_provider.dart';

enum PlayerState {
  idle,
  loading,
  playing,
  paused,
  error,
  buffering,
}

/// Unified player provider that uses:
/// - Native Android Activity (via MethodChannel) on Android TV for best 4K performance
/// - media_kit on all other platforms (Windows, Android phone/tablet, etc.)
class PlayerProvider extends ChangeNotifier {
  // media_kit player (for all platforms except Android TV)
  Player? _mediaKitPlayer;
  VideoController? _videoController;

  // Common state
  Channel? _currentChannel;
  PlayerState _state = PlayerState.idle;
  String? _error;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  bool _isMuted = false;
  double _playbackSpeed = 1.0;
  bool _isFullscreen = false;
  bool _controlsVisible = true;
  int _volumeBoostDb = 0;

  int _retryCount = 0;
  static const int _maxRetries = 2; // 改为重试2次
  Timer? _retryTimer;
  bool _isAutoSwitching = false; // 标记是否正在自动切换源
  bool _isAutoDetecting = false; // 标记是否正在自动检测源
  bool _isSoftwareDecoding = false;
  bool _noVideoFallbackAttempted = false;
  bool _allowSoftwareFallback = true;
  String _windowsHwdecMode = 'auto-safe';
  String _d3d11vppMode = 'bob';
  bool _isDisposed = false;
  StreamSubscription<VideoParams>? _videoParamsSubscription;
  bool _deinterlaceConfiguredForCurrentStream = false;
  bool _initialHwdecSet = false;
  int _deinterlaceGeneration = 0; // 代际计数器，用于检测过时的 videoParams 回调
  String _videoOutput = 'auto';
  String _vo = 'unknown';

  // Override duration for catchup playback
  Duration? _overrideDuration;

  // On Android TV, we use native player via Activity, so don't init any Flutter player
  // On Android phone/tablet and other platforms, use media_kit
  bool get _useNativePlayer => Platform.isAndroid && PlatformDetector.isTV;

  // Getters
  Player? get player => _mediaKitPlayer;
  VideoController? get videoController => _videoController;

  Channel? get currentChannel => _currentChannel;
  PlayerState get state => _state;
  String? get error => _error;
  Duration get position => _position;
  Duration get duration {
    // Return override duration if set and player reports zero/small duration
    if (_overrideDuration != null && _duration.inSeconds < 10) {
      return _overrideDuration!;
    }
    return _duration;
  }

  double get volume => _volume;
  bool get isMuted => _isMuted;
  double get playbackSpeed => _playbackSpeed;
  bool get isFullscreen => _isFullscreen;
  bool get controlsVisible => _controlsVisible;

  bool get isPlaying => _state == PlayerState.playing;
  bool get isLoading =>
      _state == PlayerState.loading || _state == PlayerState.buffering;
  bool get hasError => _state == PlayerState.error && _error != null;

  /// Create Media object with custom User-Agent header
  Media _createMedia(String url) {
    final userAgent = ServiceLocator.settings?.userAgent ?? SettingsProvider.defaultUserAgent;
    ServiceLocator.log.d('PlayerProvider: 创建Media对象 User-Agent: $userAgent');
    return Media(url, httpHeaders: {'User-Agent': userAgent});
  }

  /// Check if current content is seekable (VOD or replay)
  bool get isSeekable {
    // 1. 检查直播类型（如果明确是直播，不可拖动）
    if (_currentChannel?.isLive == true) return false;

    // 2. 检查直播类型（如果是点播或回放，可拖动）
    if (_currentChannel?.isSeekable == true) {
      // 回放内容（Replay）应该总是 seekable，即使 duration 暂时无效（可能是流加载延迟）
      // 我们信任 ChannelType.replay
      if (_currentChannel?.type == ChannelType.replay) {
        return true;
      }

      // 但还需要检查 duration 是否有效
      if (_duration.inSeconds > 0 && _duration.inSeconds <= 86400) {
        return true;
      }
    }

    // 3. 检查 duration（点播内容有明确时长）
    // 直播流通常 duration 为 0 或超大值
    if (_duration.inSeconds > 0 && _duration.inSeconds <= 86400) {
      // 有效时长（1秒到24小时），但要排除直播流
      if (_currentChannel?.isLive != true) {
        return true;
      }
    }

    // 4. 默认不可拖动（安全起见）
    return false;
  }

  /// Check if should show progress bar based on settings and content
  bool shouldShowProgressBar(String progressBarMode) {
    if (progressBarMode == 'never') return false;
    // Always show if we have an override duration (catchup)
    if (_overrideDuration != null) return true;
    if (progressBarMode == 'always') return _duration.inSeconds > 0;
    // auto mode: only show for seekable content
    return isSeekable && _duration.inSeconds > 0;
  }

  /// Set override duration for catchup playback
  void setOverrideDuration(Duration? duration) {
    _overrideDuration = duration;
    notifyListeners();
  }

  /// Check if current content is live stream
  bool get isLiveStream => !isSeekable;

  // 清除错误状态（用于显示错误后防止重复显示）
  void clearError() {
    _error = null;
    _errorDisplayed = true; // 标记错误已被显示，防止重复触发
    // 重置状态为 idle，避免 hasError 一直为 true
    if (_state == PlayerState.error) {
      _state = PlayerState.idle;
    }
    notifyListeners();
  }

  // 错误防抖：记录上次错误时间，避免短时间内重复触发
  DateTime? _lastErrorTime;
  String? _lastErrorMessage;
  bool _errorDisplayed = false; // 标记错误是否已被显示

  void _setError(String error) {
    ServiceLocator.log.d(
        'PlayerProvider: _setError 被调用 - 当前重试次数: $_retryCount/$_maxRetries, 错误: $error');

    // 忽略 seek 相关的错误（直播流不支持 seek）
    if (error.contains('seekable') ||
        error.contains('Cannot seek') ||
        error.contains('seek in this stream')) {
      ServiceLocator.log.d('PlayerProvider: 忽略 seek 错误（直播流不支持拖动）');
      return;
    }

    // 忽略音频解码警告（如果还能播放声音，这只是警告）
    if (error.contains('Error decoding audio') ||
        error.contains('audio decoder') ||
        error.contains('Audio decoding')) {
      ServiceLocator.log.d(
          'PlayerProvider: Ignore audio decode warning (likely partial frame decode failure)');
      return;
    }

    // 尝试自动重试（重试阶段不受防护限制）
    if (_retryCount < _maxRetries && _currentChannel != null) {
      _retryCount++;
      ServiceLocator.log
          .d('PlayerProvider: 播放错误，尝试重试($_retryCount/$_maxRetries): $error');
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(milliseconds: 500), () {
        if (_currentChannel != null) {
          _retryPlayback();
        }
      });
      return;
    }

    // 超过重试次数，检查是否有下一个源
    if (_currentChannel != null && _currentChannel!.hasMultipleSources) {
      final currentSourceIndex = _currentChannel!.currentSourceIndex;
      final totalSources = _currentChannel!.sourceCount;

      ServiceLocator.log
          .d('PlayerProvider: 当前源索引: $currentSourceIndex, 总源数: $totalSources');

      // 计算下一个源索引（不使用取模运算，避免循环）
      int nextIndex = currentSourceIndex + 1;

      // 检查下一个源是否存在
      if (nextIndex < totalSources) {
        // 下一个源存在，先检测再尝试
        ServiceLocator.log.d(
            'PlayerProvider: 当前源(${currentSourceIndex + 1}/$totalSources) 重试失败，检测源 ${nextIndex + 1}');

        // 标记开始自动检测
        _isAutoDetecting = true;
        // 异步检测下一个源
        _checkAndSwitchToNextSource(nextIndex, error);
        return;
      } else {
        ServiceLocator.log.d(
            'PlayerProvider: 已到最后一个源 (${currentSourceIndex + 1}/$totalSources), 停止尝试');
      }
    }

    // 没有更多源或所有源都失败，显示错误（此时才应用防抖）
    final now = DateTime.now();
    // 如果错误已经被显示过，不再设置
    if (_errorDisplayed) {
      return;
    }
    // 相同错误在30秒内不重复设置
    if (_lastErrorMessage == error &&
        _lastErrorTime != null &&
        now.difference(_lastErrorTime!).inSeconds < 30) {
      return;
    }
    _lastErrorMessage = error;
    _lastErrorTime = now;

    ServiceLocator.log.d('PlayerProvider: Playback failed, show error');
    _state = PlayerState.error;
    _error = error;
    notifyListeners();
  }

  /// 检测并切换到下一个源（用于自动切换）
  Future<void> _checkAndSwitchToNextSource(
      int nextIndex, String originalError) async {
    if (_currentChannel == null || !_isAutoDetecting) return; // 如果检测被取消，停止

    // 更新UI显示正在检测的源
    _currentChannel!.currentSourceIndex = nextIndex;
    _state = PlayerState.loading;
    notifyListeners();

    ServiceLocator.log.d(
        'PlayerProvider: 检测源 ${nextIndex + 1}/${_currentChannel!.sourceCount}');

    final testService = ChannelTestService();
    final tempChannel = Channel(
      id: _currentChannel!.id,
      name: _currentChannel!.name,
      url: _currentChannel!.sources[nextIndex],
      groupName: _currentChannel!.groupName,
      logoUrl: _currentChannel!.logoUrl,
      sources: [_currentChannel!.sources[nextIndex]],
      playlistId: _currentChannel!.playlistId,
    );

    final result = await testService.testChannel(tempChannel);

    if (!_isAutoDetecting) return; // 检测完成后再次检查是否被取消

    if (!result.isAvailable) {
      ServiceLocator.log.d(
          'PlayerProvider: 源 ${nextIndex + 1} 不可用: ${result.error}，继续尝试下一个源');

      // 检查是否还有更多源
      final totalSources = _currentChannel!.sourceCount;
      final nextNextIndex = nextIndex + 1;

      if (nextNextIndex < totalSources) {
        // 继续检测下一个源
        _checkAndSwitchToNextSource(nextNextIndex, originalError);
      } else {
        // 已到最后一个源，显示错误
        ServiceLocator.log.d('PlayerProvider: 已到最后一个源，所有源都不可用');
        _isAutoDetecting = false;
        _state = PlayerState.error;
        _error = '所有 $totalSources 个源都不可用';
        notifyListeners();
      }
      return;
    }

    ServiceLocator.log.d(
        'PlayerProvider: Source ${nextIndex + 1} is available (${result.responseTime}ms), switching');
    _isAutoDetecting = false;
    _retryCount = 0; // 重置重试计数
    _isAutoSwitching = true; // 标记为自动切换
    _lastErrorMessage = null; // 重置错误消息，允许新源的错误被处理
    _playCurrentSource();
    _isAutoSwitching = false; // 重置标记
  }

  /// 重试播放当前频道
  Future<void> _retryPlayback() async {
    if (_currentChannel == null) return;

    ServiceLocator.log.d(
        'PlayerProvider: 正在重试播放 ${_currentChannel!.name}, 当前源索引: ${_currentChannel!.currentSourceIndex}, 重试计数: $_retryCount');
    final startTime = DateTime.now();

    _state = PlayerState.loading;
    _error = null;
    notifyListeners();

    // 使用 currentUrl 而不是 url，以使用当前选择的源
    final url = _currentChannel!.currentUrl;
    ServiceLocator.log.d('PlayerProvider: 重试URL: $url');

    try {
      if (!_useNativePlayer) {
        ServiceLocator.log
            .i('>>> Retry: start resolving redirect', tag: 'PlayerProvider');
        // 解析真实播放地址（处理 302 重定向）
        final redirectStartTime = DateTime.now();

        final realUrl =
            await ServiceLocator.redirectCache.resolveRealPlayUrl(url);

        final redirectTime =
            DateTime.now().difference(redirectStartTime).inMilliseconds;
        ServiceLocator.log.i('>>> 重试: 302重定向解析完成，耗时: ${redirectTime}ms',
            tag: 'PlayerProvider');
        ServiceLocator.log.d('>>> 重试: 使用播放地址: $realUrl', tag: 'PlayerProvider');

        final playStartTime = DateTime.now();
        // 代际计数器已在 _resetDeinterlaceDetection() 中递增，确保旧回调不影响新流
        await _applyDeinterlaceFilter();
        await _mediaKitPlayer?.open(_createMedia(realUrl));

        final playTime =
            DateTime.now().difference(playStartTime).inMilliseconds;
        final totalTime = DateTime.now().difference(startTime).inMilliseconds;
        ServiceLocator.log
            .i('>>> 重试: 播放器初始化完成，耗时: ${playTime}ms', tag: 'PlayerProvider');
        ServiceLocator.log
            .i('>>> 重试: 总耗时: ${totalTime}ms', tag: 'PlayerProvider');

        _state = PlayerState.playing;
      }
      // 注意：不在这里重置 _retryCount，因为播放器可能还会异步报错
      // 重试计数会在播放真正稳定后（playing 状态持续一段时间）或切换频道时重置
      ServiceLocator.log.d('PlayerProvider: Retry command sent');
    } catch (e) {
      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log.d('PlayerProvider: 重试失败 (${totalTime}ms): $e');
      // 重试失败，继续尝试或显示错误
      _setError('Failed to play channel: $e');
    }
    notifyListeners();
  }

  String _hwdecMode = 'unknown';
  String _videoCodec = '';
  double _fps = 0;

  // 保存初始化时的 hwdec 配置
  String _configuredHwdec = 'unknown';

  // FPS 显示
  double _currentFps = 0;

  // 视频信息
  int _videoWidth = 0;
  int _videoHeight = 0;
  double _downloadSpeed = 0; // bytes per second

  // 音频信息
  String _audioCodec = '';
  int _audioChannels = 0;

  double get currentFps => _currentFps;
  int get videoWidth => _videoWidth;
  int get videoHeight => _videoHeight;
  double get downloadSpeed => _downloadSpeed;

  String get videoInfo {
    if (_mediaKitPlayer == null) return '';
    final w = _mediaKitPlayer!.state.width;
    final h = _mediaKitPlayer!.state.height;
    if (w == 0 || h == 0) return '';
    final parts = <String>['${w}x$h'];
    if (_videoCodec.isNotEmpty) parts.add(_videoCodec);
    if (_fps > 0) parts.add('${_fps.toStringAsFixed(1)} fps');
    // 音频格式
    if (_audioCodec.isNotEmpty) {
      final audioPart = StringBuffer(_audioCodec);
      if (_audioChannels > 0) {
        audioPart.write(' | $_audioChannels声道');
      }
      parts.add(audioPart.toString());
    }
    final hwdecInfo = _formatHwdecInfo();
    if (hwdecInfo.isNotEmpty) {
      parts.add('hwdec: $hwdecInfo');
    }
    // 码率显示（基于预估下载速度）
    if (_downloadSpeed > 0) {
      final bitrateMbps = _downloadSpeed * 8 / 1000000;
      if (bitrateMbps >= 100) {
        parts.add('${bitrateMbps.toStringAsFixed(0)} Mbps');
      } else {
        parts.add('${bitrateMbps.toStringAsFixed(1)} Mbps');
      }
    }
    return parts.join(' | ');
  }

  double get progress {
    if (_duration.inMilliseconds == 0) return 0;
    return _position.inMilliseconds / _duration.inMilliseconds;
  }

  PlayerProvider() {
    _initPlayer();
  }

  void _initPlayer({bool useSoftwareDecoding = false}) {
    // On Android TV, we use native player - don't initialize any Flutter player
    if (_useNativePlayer) {
      return;
    }

    // 其他平台（包括 Android 手机）都使用 media_kit
    _initMediaKitPlayer(useSoftwareDecoding: useSoftwareDecoding);
  }

  /// 预热播放器 - 在应用启动时调用,提前初始化播放器资源
  /// 这样首次进入播放页面时就不会卡顿
  Future<void> warmup() async {
    if (_useNativePlayer) {
      return; // 原生播放器不需要预热
    }

    if (_mediaKitPlayer == null) {
      ServiceLocator.log
          .d('PlayerProvider: 预热播放器 - 初始化 media_kit', tag: 'PlayerProvider');
      _initMediaKitPlayer();
    }

    // 使用空 Media 预热会触发错误回调，可能导致首次播放黑屏/蓝屏
    // 目前只做实例初始化，不做无效流程预加载
  }

  Future<void> _initMediaKitPlayer(
      {bool useSoftwareDecoding = false, String bufferStrength = 'fast'}) async {
    _mediaKitPlayer?.dispose();
    _debugInfoTimer?.cancel();
    // Load decoding settings (overridden by explicit useSoftwareDecoding)
    final prefs = ServiceLocator.prefs;
    final decodingMode = prefs.getString('decoding_mode') ?? 'auto';
    _windowsHwdecMode = prefs.getString('windows_hwdec_mode') ?? 'auto-safe';
    // d3d11vpp 去交错模式：校验合法性，避免残留非法值
    final savedD3d11vpp = prefs.getString('d3d11vpp_mode');
    _d3d11vppMode =
        (savedD3d11vpp != null && SettingsProvider.d3d11vppModes.contains(savedD3d11vpp))
            ? savedD3d11vpp
            : 'bob';
    _allowSoftwareFallback = prefs.getBool('allow_software_fallback') ?? true;
    _videoOutput = prefs.getString('video_output') ?? 'auto';
    final effectiveSoftware = useSoftwareDecoding || decodingMode == 'software';
    _isSoftwareDecoding = effectiveSoftware;

    ServiceLocator.log.i('========== 初始化播放器 ==========', tag: 'PlayerProvider');
    ServiceLocator.log
        .i('平台: ${Platform.operatingSystem}', tag: 'PlayerProvider');
    ServiceLocator.log.i('软解码模式: $useSoftwareDecoding', tag: 'PlayerProvider');
    ServiceLocator.log.i('缓冲强度: $bufferStrength', tag: 'PlayerProvider');

    // 根据缓冲强度设置缓冲区大小
    final bufferSize = switch (bufferStrength) {
      'fast' => 32 * 1024 * 1024, // 32MB - 快速启动
      'balanced' => 64 * 1024 * 1024, // 64MB - 平衡模式
      'stable' => 128 * 1024 * 1024, // 128MB - 稳定优先
      _ => 32 * 1024 * 1024,
    };

    String? vo;
    switch (_videoOutput) {
      case 'gpu':
        vo = 'gpu';
        break;
      case 'libmpv':
        vo = 'libmpv';
        break;
      case 'auto':
      default:
        vo = null;
        break;
    }

    _mediaKitPlayer = Player(
      configuration: PlayerConfiguration(
        bufferSize: bufferSize,
        vo: vo,
        // 协议白名单：media_kit 默认不含 rtsp，需在此加入以支持 RTSP 播放
        // （media_kit 通过 demuxer-lavf-o=protocol_whitelist 传给 mpv，
        //  运行时的 setProperty('protocol-whitelist') 无法覆盖该层）
        protocolWhitelist: const [
          'udp', 'rtp', 'rtsp', 'tcp', 'tls', 'data', 'file', 'http', 'https', 'crypto',
        ],
        // 设置网络超时（可选）
        // timeout: 3 秒连接最长超时
        // 根据日志级别启用 mpv 日志
        logLevel: ServiceLocator.log.currentLevel == LogLevel.debug
            ? MPVLogLevel.debug
            : (ServiceLocator.log.currentLevel == LogLevel.off
                ? MPVLogLevel.error
                : MPVLogLevel.info),
      ),
    );

    // 确定硬件解码模式
    String? hwdecMode;
    if (Platform.isAndroid) {
      hwdecMode = effectiveSoftware ? 'no' : 'mediacodec';
    } else if (Platform.isWindows) {
      if (effectiveSoftware) {
        hwdecMode = 'no';
      } else {
        switch (_windowsHwdecMode) {
          case 'auto-copy':
            hwdecMode = 'auto-copy';
            break;
          case 'd3d11va':
            hwdecMode = 'd3d11va';
            break;
          case 'dxva2':
            hwdecMode = 'dxva2';
            break;
          case 'auto-safe':
          default:
            hwdecMode = 'auto-safe';
            break;
        }
      }
    }

    _configuredHwdec = hwdecMode ?? 'default';
    ServiceLocator.log.i('硬件解码模式: ${hwdecMode ?? "默认"}', tag: 'PlayerProvider');
    ServiceLocator.log
        .i('硬件加速: ${!effectiveSoftware}', tag: 'PlayerProvider');

    VideoControllerConfiguration config = VideoControllerConfiguration(
      hwdec: hwdecMode,
      enableHardwareAcceleration: !effectiveSoftware,
    );

    // 默认显示为配置值，后续可被实际运行时覆盖
    _hwdecMode = effectiveSoftware ? 'no' : _configuredHwdec;
    _vo = vo ?? 'auto';

    _videoController = VideoController(_mediaKitPlayer!, configuration: config);
    _setupMediaKitListeners();
    _updateDebugInfo();

    // VideoController 创建后会强制设 hwdec=auto，在此覆盖去交错参数
    // 必须在 open() 之前调用，否则 hwdec=auto 会绕过 vf 滤镜链
    // 重置 _initialHwdecSet 确保新播放器的 hwdec 被正确设置
    _initialHwdecSet = false;
    _resetDeinterlaceDetection();
    await _applyDeinterlaceFilter();

    ServiceLocator.log.i('播放器初始化完成', tag: 'PlayerProvider');
  }

  /// 安全调用 setProperty，单个失败不影响其他调用
  /// 返回 true 表示成功，false 表示失败
  Future<bool> _safeSetProperty(String property, String value, String label) async {
    try {
      final nativePlayer = player?.platform as dynamic;
      await nativePlayer.setProperty(property, value);
      return true;
    } catch (e) {
      ServiceLocator.log.d('设置 $label 失败: $e', tag: 'PlayerProvider');
      return false;
    }
  }

  /// 安全读取 getProperty，失败返回 null
  Future<String?> _safeGetProperty(String property, String label) async {
    try {
      final nativePlayer = player?.platform as dynamic;
      return await nativePlayer.getProperty(property);
    } catch (e) {
      ServiceLocator.log.d('读取 $label 失败: $e', tag: 'PlayerProvider');
      return null;
    }
  }

  /// 验证滤镜链/去交错是否真正生效（修复验证盲区）
  ///
  /// mpv 设置 `vf` 或 `deinterlace` 后是异步重建滤镜链，失败时（如硬件格式
  /// 不兼容）会输出 "Disabling filter ... because it has failed"，或通过 error
  /// 流抛 "Error parsing option ..." 等异常。仅检查属性/只监听 log 流都可能在
  /// 异常经 error 流抛出时漏判。因此同时监听 log 流与 error 流：两者均无失败
  /// 信号则视为生效。
  Future<bool> _verifyFilterChainActive(String label) async {
    final failureSignaled = Completer<bool>();

    void checkFailure(String msg) {
      if (msg.contains('Disabling filter') ||
          msg.contains('Impossible to convert') ||
          msg.contains('failed to configure the filter graph') ||
          msg.contains('no such filter') ||
          msg.contains('error creating filters') ||
          msg.contains('Error parsing option') ||
          msg.contains('option not found')) {
        if (!failureSignaled.isCompleted) failureSignaled.complete(true);
      }
    }

    final logSub = _mediaKitPlayer!.stream.log.listen((log) => checkFailure(log.text));
    final errSub = _mediaKitPlayer!.stream.error.listen((err) {
      if (err.isNotEmpty) checkFailure(err);
    });

    final failed = await failureSignaled.future.timeout(
      const Duration(milliseconds: 350),
      onTimeout: () => false, // 超时未出现失败信号 => 视为滤镜链生效
    );
    await logSub.cancel();
    await errSub.cancel();
    if (failed) {
      ServiceLocator.log.d('滤镜链验证失败($label): 检测到 mpv 滤镜配置错误', tag: 'PlayerProvider');
    }
    return !failed;
  }

  /// 返回用户配置的 hwdec 模式，考虑软解码设置
  String _getConfiguredHwdecMode() {
    if (_isSoftwareDecoding) return 'no';
    switch (_windowsHwdecMode) {
      case 'auto-copy':
        return 'auto-copy';
      case 'd3d11va':
        return 'd3d11va';
      case 'dxva2':
        return 'dxva2';
      case 'auto-safe':
      default:
        return 'auto-safe';
    }
  }

  /// 重置去交错检测状态，取消 videoParams 监听订阅
  /// 在每次播放新流之前调用，确保旧流监听不会影响新流。
  /// 递增代际计数器使正在执行的旧异步回调在设置 guard 前检测到代际变化并忽略。
  ///
  /// 注意：不重置 _initialHwdecSet，避免每次换台同步阶段重新设置 hwdec
  /// 触发 mpv 视频链初始化导致的 1-2s 延迟。hwdec 仅在首次创建播放器时设置，
  /// 异步阶段根据源类型（1080i/逐行）做增量调整。
  void _resetDeinterlaceDetection() {
    _deinterlaceGeneration++; // 递增代际，使正在执行的旧回调失效
    _videoParamsSubscription?.cancel();
    _videoParamsSubscription = null;
    _deinterlaceConfiguredForCurrentStream = false;
  }

  /// 应用去交错（反隔行）配置
  ///
  /// 时序分两阶段：
  ///   1. 同步阶段（open() 之前调用）：
  ///      - 设置公共参数 video-sync / framedrop
  ///      - 设置 deinterlace=no, vf=``（清除旧滤镜残留）
  ///      - 仅在首次创建播放器时设置 hwdec（通过 _initialHwdecSet 控制）
  ///   2. 异步阶段（videoParams 流回调，open() 之后）：
  ///      - 补读 interlaced / gamma / primaries 等属性
  ///      - 根据源类型做增量调整：
  ///        - 1080i: 切换 hwdec=d3d11va-copy + 尝试软件 vf 滤镜
  ///        - 逐行源: 重置 hwdec 为用户配置模式，清除上一流可能残留的 d3d11va-copy
  ///      - 部分场景（软件滤镜失败）回退硬件去交错
  ///
  /// 注意：每次切换频道前必须调用 _resetDeinterlaceDetection() 递增代际计数器，
  /// 确保旧的 videoParams 异步回调不会干扰新流的配置。
  /// _initialHwdecSet 仅在创建新播放器时重置，不随换台重置，避免不必要的 hwdec
  /// 设置触发 mpv 视频链初始化延迟。
  Future<void> _applyDeinterlaceFilter() async {
    if (!Platform.isWindows) return;
    final prefs = ServiceLocator.prefs;
    final enabled = prefs.getBool('deinterlace_enabled') ?? true;

    // 公共参数：所有源均使用 display-resample 同步
    await _safeSetProperty('video-sync', 'display-resample', 'video-sync');
    await _safeSetProperty('framedrop', 'vo', 'framedrop');

    // 允许 RTSP 协议：media_kit 默认 protocol-whitelist 不含 rtsp，
    // 会导致 avformat_open_input() 失败并报 "Protocol 'rtsp' not on whitelist"
    // 覆盖为包含 rtsp（及底层 udp/rtp/tcp）的安全白名单
    await _safeSetProperty(
        'protocol-whitelist',
        'udp,rtp,rtsp,tcp,tls,data,file,http,https,crypto',
        'protocol-whitelist');

    // ═══════════════════════════════════════════════
    // 同步阶段（open() 之前）：设置解码器启动参数
    // ═══════════════════════════════════════════════
    if (enabled) {
      // 启用去交错：使用用户配置的 hwdec 模式（如 auto-safe、auto-copy 等）
      // - 不使用硬编码 d3d11va-copy：某些 HEVC 4K 流在 d3d11va-copy 下解码失败（PPS id out of range）
      // - 异步 videoParams 回调确认是 1080i 后，才会切换为 d3d11va-copy 以支持软件 vf 滤镜
      // - 对逐行 4K 源：保持用户配置的 hwdec，避免解码器不兼容
      // hwdec 只在首次设置，避免 open() 后重复设置触发解码器重建
      if (!_initialHwdecSet) {
        await _safeSetProperty('hwdec', _getConfiguredHwdecMode(), 'hwdec');
        _initialHwdecSet = true;
      }
      await _safeSetProperty('deinterlace', 'no', 'deinterlace');
      await _safeSetProperty('vf', '', 'clear_vf');
    } else {
      // 禁用去交错：使用用户配置的 hwdec
      await _safeSetProperty('deinterlace', 'no', 'deinterlace');
      await _safeSetProperty('vf', '', 'clear_vf');
      if (!_initialHwdecSet) {
        await _safeSetProperty('hwdec', _getConfiguredHwdecMode(), 'hwdec');
        _initialHwdecSet = true;
      }
      _videoParamsSubscription?.cancel();
      _videoParamsSubscription = null;
      ServiceLocator.log.i('去交错已禁用', tag: 'PlayerProvider');
      return;
    }

    // ═══════════════════════════════════════════════
    // 异步阶段（open() 之后）：videoParams 流回调，增量调整
    // ═══════════════════════════════════════════════
    // 仅当尚未设置监听器时设置（避免重复订阅）
    // 每次播放新流前通过 _resetDeinterlaceDetection() 取消旧订阅
    if (_videoParamsSubscription == null) {
      _deinterlaceConfiguredForCurrentStream = false;
      _videoParamsSubscription = _mediaKitPlayer?.stream.videoParams.listen((params) async {
        // 捕获当前代际，用于检测过时的回调
        final capturedGeneration = _deinterlaceGeneration;
        // 等待有效数据（w > 0 && h > 0），且防重入
        if (_deinterlaceConfiguredForCurrentStream || params.w == null || params.w! <= 0) return;

        // 补读 video-frame-info/interlaced — VideoParams 不含此字段
        final interlaced = await _safeGetProperty('video-frame-info/interlaced', 'interlaced');
        // 补读 estimated-vf-fps 辅助判定
        final vfFpsStr = await _safeGetProperty('estimated-vf-fps', 'vf-fps');
        final vfFps = double.tryParse(vfFpsStr ?? '') ?? 0;

        // 读取源端实际色彩空间，用于动态 HDR/SDR 判定
        // 注意：色彩空间信息（gamma/primaries）可能延迟就绪，需先检查再设置 guard
        final srcGamma = await _safeGetProperty('video-params/gamma', 'gamma');
        final srcPrimaries = await _safeGetProperty('video-params/primaries', 'primaries');

        // 如果 HDR 元数据尚未就绪，不设置 guard 标志，等待下次 videoParams 事件重试
        if (srcGamma == null || srcGamma.isEmpty || srcPrimaries == null || srcPrimaries.isEmpty) {
          ServiceLocator.log.d(
              '色彩空间信息尚未就绪 (gamma=$srcGamma, primaries=$srcPrimaries)，延迟到下次 videoParams 事件配置',
              tag: 'PlayerProvider');
          return;
        }

        // 检查代际：如果在此期间 _resetDeinterlaceDetection() 被调用（快速切换频道），
        // 当前回调属于旧流，不应再设置 guard 或配置参数，让新流的回调来处理
        if (capturedGeneration != _deinterlaceGeneration) {
          ServiceLocator.log.d('videoParams 回调已过时（代际变化），忽略', tag: 'PlayerProvider');
          return;
        }

        _deinterlaceConfiguredForCurrentStream = true;

        final sigPeak = await _safeGetProperty('video-params/sig-peak', 'sig-peak');

        // 读取 codec 用于预设规则
        final codec = await _safeGetProperty('video-params/codec', 'codec');

        final h = params.h ?? 0;
        final w = params.w ?? 0;
        final isInterlaced = interlaced == '1';

        // 1080i 判定：标准检测 + 帧率兜底 + 预设规则
        // 预设规则：H.264 + 1920×1080 的直播源，中国广电通常为 1080i50
        // 即使首帧 interlaced 字段不稳定，也能正确启用去隔行
        final is1080i = (h == 1080 && isInterlaced) ||
                        (h == 1080 && vfFps < 31 && interlaced != '0') ||
                        (codec == 'h264' && h == 1080 && w == 1920);
        // HDR 判定：BT.2020 色域 + (PQ 或 HLG 伽马曲线)
        final isHDR = srcPrimaries == 'bt.2020' &&
                      (srcGamma == 'pq' || srcGamma == 'hlg');

        // ════════════════════════════════════════════
        // 第一步：动态色彩映射 — 先判断 HDR/SDR，再决定色彩参数
        // ════════════════════════════════════════════
        if (isHDR) {
          if (srcGamma == 'hlg') {
            // HLG 广播源：HLG 设计为兼容 SDR 显示器，75% 电平即 100% SDR 白
            // 不干预色彩，让 mpv 走默认的 HLG→SDR 广播标准下变换
            await _safeSetProperty('hdr-compute-peak', 'yes', 'hdr-compute-peak');
            ServiceLocator.log.i(
                'HDR 源(HLG): mpv 默认 HLG→SDR 转换 (gamma=$srcGamma, primaries=$srcPrimaries)',
                tag: 'PlayerProvider');
          } else {
            // PQ/HDR10 源：主动色调映射到 SDR
            await _safeSetProperty('target-prim', 'bt.709', 'target-prim');
            await _safeSetProperty('target-trc', 'bt.1886', 'target-trc');
            await _safeSetProperty('tone-mapping', 'bt.2390', 'tone-mapping');
            await _safeSetProperty('tone-mapping-param', 'default', 'tone-mapping-param');
            await _safeSetProperty('hdr-compute-peak', 'yes', 'hdr-compute-peak');
            await _safeSetProperty('target-peak', '100', 'target-peak');
            ServiceLocator.log.i(
                'HDR 源(PQ/HDR10): 色调映射到 SDR (gamma=$srcGamma, primaries=$srcPrimaries, sig-peak=$sigPeak)',
                tag: 'PlayerProvider');
          }
        } else {
          // SDR 源（包括 4K SDR、1080p 等）：清零所有 HDR 残留参数
          await _safeSetProperty('target-prim', 'auto', 'target-prim');
          await _safeSetProperty('target-trc', 'auto', 'target-trc');
          await _safeSetProperty('hdr-compute-peak', 'no', 'hdr-compute-peak');
          ServiceLocator.log.i(
              'SDR 源: 标准输出 (gamma=$srcGamma, primaries=$srcPrimaries)',
              tag: 'PlayerProvider');
        }

        // ════════════════════════════════════════════
        // 第二步：去交错增量配置 — 根据源类型选择性调整 hwdec
        // ════════════════════════════════════════════
        if (is1080i && !_isSoftwareDecoding) {
          // 分支 A: 1080i 隔行源 — 按所选硬解方案分流
          //
          // auto-safe（safe 系）：mpv 自动选 direct 解码（d3d11va）。direct 帧是
          //   d3d11 硬件表面，软件 bwdif 无法消费，因此用 vf=d3d11vpp（参数可配置）
          //   或 deinterlace=yes 硬件去交错，不碰 copy，避免解码器重建。
          // d3d11va/dxva2（非 safe direct 系）：deinterlace=yes 硬件去交错。
          // auto-copy（copy 系）：帧是软件可消费的 copy-back 帧，走软件 bwdif，
          //   失败再回退硬件去交错。
          final isSafeFlow = _windowsHwdecMode == 'auto-safe';
          final isDirectFlow = _windowsHwdecMode == 'd3d11va' ||
              _windowsHwdecMode == 'dxva2';
          final isCopyFlow = _windowsHwdecMode == 'auto-copy';

          if (isSafeFlow) {
            // —— auto-safe 流：vf=d3d11vpp 硬件去交错（参数可配置，非 safe 不生效） ——
            await _safeSetProperty('deinterlace', 'no', 'deinterlace');
            await _safeSetProperty('vf', '', 'clear_vf');
            if (_d3d11vppMode == 'off') {
              // 用户关闭 d3d11vpp → 回退硬件 VPP
              await _safeSetProperty('deinterlace', 'yes', 'deinterlace');
              ServiceLocator.log.i(
                  '1080i: auto-safe 流 d3d11vpp 关闭，使用 deinterlace=yes',
                  tag: 'PlayerProvider');
            } else {
              final vfStr = 'd3d11vpp=mode=$_d3d11vppMode:deint=yes:interlaced-only=yes';
              await _safeSetProperty('vf', vfStr, 'vf_d3d11vpp');
              final ok = await _verifyFilterChainActive('vf=$vfStr');
              if (ok) {
                ServiceLocator.log.i(
                    '1080i: auto-safe 流使用 d3d11vpp ($_d3d11vppMode) 硬件去交错',
                    tag: 'PlayerProvider');
              } else {
                await _safeSetProperty('vf', '', 'clear_vf');
                await _safeSetProperty('deinterlace', 'yes', 'deinterlace');
                ServiceLocator.log.i(
                    '1080i: auto-safe 流 d3d11vpp 不可用，退回 deinterlace=yes',
                    tag: 'PlayerProvider');
              }
            }
          } else if (isDirectFlow) {
            // —— 非 safe direct 流：deinterlace=yes 硬件去交错，零重建 ——
            await _safeSetProperty('vf', '', 'clear_vf');
            await _safeSetProperty('deinterlace', 'yes', 'deinterlace');
            ServiceLocator.log.i(
                '1080i: direct 流($_windowsHwdecMode) 使用硬件去交错 (deinterlace=yes)',
                tag: 'PlayerProvider');
          } else if (isCopyFlow) {
            // —— copy 流：软件 bwdif 优先，硬件兜底 ——
            await _safeSetProperty('deinterlace', 'no', 'deinterlace');
            await _safeSetProperty('vf', '', 'clear_vf');

            // 读取当前实际 hwdec 配置，判断是否需强制切到 copy-back 模式。
            // 反转判断：仅当明确读到 direct 模式（d3d11va/dxva2）才强制切 d3d11va-copy；
            // 读到 null/未知/auto/copy 一律不切换，避免在 videoParams 回调属性未就绪时
            // 误判为"非 copy"而反复触发解码器重建（造成约 1s 缓冲波动）。
            final currentHwdec = await _safeGetProperty('hwdec', 'hwdec');
            final needCopyForSoftwareFilter = currentHwdec == 'd3d11va' || currentHwdec == 'dxva2';
            if (needCopyForSoftwareFilter) {
              // 仅在 direct 模式时切换到 d3d11va-copy，使软件滤镜能消费帧
              await _safeSetProperty('hwdec', 'd3d11va-copy', 'hwdec_1080i');
            }

            const filters = [
              'bwdif=mode=1:parity=tff',
              'lavfi:yadif=mode=1:parity=tff',
            ];

            String? workingFilter;
            for (int retry = 0; retry < 5 && workingFilter == null; retry++) {
              if (retry > 0) await Future.delayed(const Duration(milliseconds: 50));
              for (final vf in filters) {
                await _safeSetProperty('vf', '', 'clear_vf');
                // 只有 setProperty 真正成功才做日志/error 联动验证；
                // 若 setProperty 直接抛异常（如非法滤镜 "Error parsing option"），
                // 直接跳过该滤镜尝试，不进入验证窗口。
                final setOk = await _safeSetProperty('vf', vf, 'try_vf');
                if (!setOk) continue;
                if (await _verifyFilterChainActive('vf=$vf')) {
                  workingFilter = vf;
                  ServiceLocator.log.i(
                      '1080i: 软件滤镜 $vf 生效 (hwdec=$currentHwdec)',
                      tag: 'PlayerProvider');
                  break;
                }
              }
            }

            if (workingFilter == null) {
              // 软件滤镜全部不可用 → 回退到硬件去交错
              await _safeSetProperty('vf', '', 'clear_vf');
              await _safeSetProperty('hwdec', _getConfiguredHwdecMode(), 'hwdec');
              await _safeSetProperty('deinterlace', 'yes', 'deinterlace');
              ServiceLocator.log.i(
                  '1080i: 软件滤镜不可用，退回硬件去交错 (deinterlace=yes)',
                  tag: 'PlayerProvider');
            }
          }
          // 其它未知配置：不干预，保持现状（用户配置指定）
        } else {
          // 分支 B: 逐行源（1080p / 2160p SDR / 2160p HDR 等）
          // 仅当 hwdec 类别与用户配置不一致时才重置，清除上一流可能残留的
          // d3d11va-copy；若类别一致（如同为 copy 系）则不重置，
          // 避免 1080i→4K 切换时 hwdec 值变动触发解码器重建导致播放器重置
          final targetHwdec = _getConfiguredHwdecMode();
          // 读取当前实际 hwdec（hwdec-current），未知时按空处理
          final readHwdec = await _safeGetProperty('hwdec-current', 'hwdec-current');
          final currentHwdec = readHwdec ?? '';
          // 目标与当前的 copy/direct 类别是否一致（copy-back 语义相同时无需重建）
          final isCopyTarget = targetHwdec == 'auto-copy' || targetHwdec.endsWith('-copy');
          final isCopyActual = currentHwdec.endsWith('-copy') || currentHwdec == 'auto-copy';
          if (readHwdec == null || readHwdec.isEmpty || isCopyTarget != isCopyActual) {
            // 类别不一致或未知：显式重置为用户配置的 hwdec
            await _safeSetProperty('hwdec', targetHwdec, 'hwdec_progressive');
          }
          await _safeSetProperty('deinterlace', 'no', 'deinterlace');
          await _safeSetProperty('vf', '', 'clear_vf');
          final label = h > 0 ? '${h}p 逐行源' : '源（默认按逐行处理）';
          ServiceLocator.log.i('$label: $targetHwdec 硬解(当前$currentHwdec), 无去交错', tag: 'PlayerProvider');
        }
      });
    }
  }

  void _setupMediaKitListeners() {
    ServiceLocator.log.d('设置播放器监听器', tag: 'PlayerProvider');

    // 始终激活 mpv 日志监听器，确保所有冗余日志被过滤
    // 不依赖 LogLevel 开关，因为 mpv 日志过滤对于保持输出干净至关重要
    _mediaKitPlayer!.stream.log.listen((log) {
      final message = log.text.toLowerCase();

      // 过滤 FFmpeg 噪音日志（SEI truncated、mmco、reference frames 等）
      if (message.contains('sei type') ||
          message.contains('truncated at') ||
          message.contains('mmco') ||
          message.contains('reference frames') ||
          message.contains('exceeds max') ||
          message.contains('discarding one') ||
          message.contains('deprecated pixel format') ||
          message.contains("skip ('#ext") ||
          (message.contains('hls @') && message.contains('skip')) ||
          message.contains('no such filter') ||
          message.contains('error creating filters')) {
        return;
      }

      // 根据当前日志级别决定是否转发
      if (ServiceLocator.log.currentLevel != LogLevel.off) {
        ServiceLocator.log.d('MPV log: ${log.text}', tag: 'PlayerProvider');
      }

        // 检测并记录解码信息：统一使用 [Decoder] 前缀，精确解析实际解码器。
      // 之前用多个互斥 if 分支按关键字模糊匹配（hwdec→"硬件解码"、d3d11→
      // "软件解码"等），同一条 MPV 日志常命中多个分支，被重复打上互相矛盾的
      // 标签（如 "使用硬件解码" 与 "使用软件解码" 同时出现），严重误导排查。
      // 现在只在实际解码器/输出驱动变化时记录一条统一标签的日志。
      if (message.contains('using hardware decoding') ||
          message.contains('software decoding') ||
          message.contains('hwdec') ||
          message.contains('video output driver') ||
          message.contains('vo:')) {
        final hwdecBefore = _hwdecMode;
        final voBefore = _vo;
        _updateHwdecFromLog(message);
        _updateVoFromLog(message);
        if (_hwdecMode != hwdecBefore || _vo != voBefore) {
          ServiceLocator.log.i(
              '[Decoder] hwdec: $_hwdecMode, vo: $_vo (${log.text})',
              tag: 'PlayerProvider');
        }
      }

      // 记录错误和警告
      if (log.level == 'error') {
        ServiceLocator.log.e('MPV错误: ${log.text}', tag: 'PlayerProvider');
      } else if (log.level == 'warn') {
        ServiceLocator.log.w('MPV警告: ${log.text}', tag: 'PlayerProvider');
      }
      });

    _mediaKitPlayer!.stream.playing.listen((playing) {
      ServiceLocator.log.d('播放状态变化: playing=$playing', tag: 'PlayerProvider');
      if (playing) {
        _state = PlayerState.playing;
        // 只有在播放稳定后才重置重试计数
        // 使用延迟确保播放真正开始，而不是短暂的状态变化
        Future.delayed(const Duration(seconds: 3), () {
          if (_state == PlayerState.playing && _currentChannel != null) {
            ServiceLocator.log
                .d('PlayerProvider: Playback stable, reset retry count');
            _retryCount = 0;
          }
        });
      } else if (_state == PlayerState.playing) {
        _state = PlayerState.paused;
      }
      notifyListeners();
    });

    _mediaKitPlayer!.stream.buffering.listen((buffering) {
      ServiceLocator.log.d('缓冲状态: buffering=$buffering', tag: 'PlayerProvider');
      if (buffering &&
          _state != PlayerState.idle &&
          _state != PlayerState.error) {
        _state = PlayerState.buffering;
      } else if (!buffering && _state == PlayerState.buffering) {
        _state = _mediaKitPlayer!.state.playing
            ? PlayerState.playing
            : PlayerState.paused;
      }
      notifyListeners();
    });

    _mediaKitPlayer!.stream.position.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _mediaKitPlayer!.stream.duration.listen((dur) {
      _duration = dur;
      notifyListeners();
    });

    _mediaKitPlayer!.stream.tracks.listen((tracks) {
      ServiceLocator.log.d(
          '轨道信息更新: 视频轨:${tracks.video.length}, 音频轨:${tracks.audio.length}',
          tag: 'PlayerProvider');

      for (final track in tracks.video) {
        if (track.codec != null) {
          _videoCodec = track.codec!;
          ServiceLocator.log.i('视频编码: ${track.codec}', tag: 'PlayerProvider');
        }
        if (track.fps != null) {
          _fps = track.fps!;
          ServiceLocator.log
              .i('视频帧率: ${track.fps} fps', tag: 'PlayerProvider');
        }
        if (track.w != null && track.h != null) {
          ServiceLocator.log
              .i('视频分辨率: ${track.w}x${track.h}', tag: 'PlayerProvider');
        }
      }

      for (final track in tracks.audio) {
        if (track.codec != null) {
          _audioCodec = track.codec!;
          ServiceLocator.log.i('音频编码: ${track.codec}', tag: 'PlayerProvider');
        }
      }

      notifyListeners();
    });

    _mediaKitPlayer!.stream.volume.listen((vol) {
      _volume = vol / 100;
      notifyListeners();
    });

    _mediaKitPlayer!.stream.error.listen((err) {
      if (err.isNotEmpty) {
        ServiceLocator.log.e('播放器错误: $err', tag: 'PlayerProvider');

        // 分析错误类型
        if (err.toLowerCase().contains('decode') ||
            err.toLowerCase().contains('decoder')) {
          ServiceLocator.log.e('>>> 解码错误: $err', tag: 'PlayerProvider');
        } else if (err.toLowerCase().contains('render') ||
            err.toLowerCase().contains('display')) {
          ServiceLocator.log.e('>>> 网络错误: $err', tag: 'PlayerProvider');
        } else if (err.toLowerCase().contains('hwdec') ||
            err.toLowerCase().contains('hardware')) {
          ServiceLocator.log.e('>>> 硬件加速错误: $err', tag: 'PlayerProvider');
        } else if (err.toLowerCase().contains('codec')) {
          ServiceLocator.log.e('>>> 解码器错误: $err', tag: 'PlayerProvider');
        }

        if (_shouldTrySoftwareFallback(err)) {
          ServiceLocator.log.w('尝试软件回退', tag: 'PlayerProvider');
          _attemptSoftwareFallback();
        } else {
          _setError(err);
        }
      }
    });

    _mediaKitPlayer!.stream.width.listen((width) {
      if (width != null && width > 0) {
        ServiceLocator.log.d('视频宽度: $width', tag: 'PlayerProvider');
      }
      notifyListeners();
    });

    _mediaKitPlayer!.stream.height.listen((height) {
      if (height != null && height > 0) {
        ServiceLocator.log.d('视频高度: $height', tag: 'PlayerProvider');
      }
      notifyListeners();
    });
  }

  Timer? _debugInfoTimer;

  void _updateDebugInfo() {
    _debugInfoTimer?.cancel();

    _debugInfoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_mediaKitPlayer == null) return;

      // 如果线程未开启或尚未解析到实际值，使用配置值兜底
      if (ServiceLocator.log.currentLevel == LogLevel.off &&
          (_hwdecMode == 'unknown' || _hwdecMode.isEmpty)) {
        _hwdecMode = _configuredHwdec;
      }

      // 实时读取 hwdec-current 属性，显示实际使用的硬件解码模式
      // 避免仅显示配置值（如 auto-safe），而实际可能已切换为 d3d11va-copy
      _safeGetProperty('hwdec-current', 'hwdec-current').then((current) {
        if (current != null && current.isNotEmpty && current != _hwdecMode) {
          _hwdecMode = current;
          notifyListeners();
        }
      });

      // 实时读取 vo 属性，显示实际视频输出驱动（如 libmpv/gpu-next）
      // 避免仅显示配置值（auto），日志解析存在覆盖/缺失的不可靠情况
      _safeGetProperty('vo', 'vo').then((current) {
        if (current != null && current.isNotEmpty && current != _vo) {
          _vo = current.split(',').first.trim();
          notifyListeners();
        }
      });

      // 实时读取音频信息
      _safeGetProperty('audio-params/codec', 'audio-codec').then((codec) {
        if (codec != null && codec.isNotEmpty && codec != _audioCodec) {
          _audioCodec = codec;
          notifyListeners();
        }
      });
      _safeGetProperty('audio-params/channels', 'audio-channels').then((ch) {
        final chCount = _parseChannelCount(ch ?? '');
        if (chCount > 0 && chCount != _audioChannels) {
          _audioChannels = chCount;
          notifyListeners();
        }
      });

      // 更新视频宽高
      final newWidth = _mediaKitPlayer!.state.width ?? 0;
      final newHeight = _mediaKitPlayer!.state.height ?? 0;

      // 检测视频尺寸变化（可能表示解码成功）
      if (newWidth != _videoWidth || newHeight != _videoHeight) {
        if (newWidth > 0 && newHeight > 0) {
          ServiceLocator.log.i('视频解码成功: ${newWidth}x$newHeight',
              tag: 'PlayerProvider');
        } else if (_videoWidth > 0 && newWidth == 0) {
          ServiceLocator.log.w('视频解码失败', tag: 'PlayerProvider');
        }
      }

      _videoWidth = newWidth;
      _videoHeight = newHeight;

      // Windows 端直接使用 track 中的 fps 信息
      // media_kit (mpv) 的显示帧率等于视频源帧率
      if (_state == PlayerState.playing && _fps > 0) {
        _currentFps = _fps;
      } else {
        _currentFps = 0;
      }

      // 实时码率 - 读取 mpv 的 video-bitrate 和 audio-bitrate 属性
      // 单位为 bps（bits per second），转成 bytes per second 存入 _downloadSpeed
      if (_state == PlayerState.playing) {
        _safeGetProperty('video-bitrate', 'video-bitrate').then((v) {
          _safeGetProperty('audio-bitrate', 'audio-bitrate').then((a) {
            final vBps = double.tryParse(v ?? '');
            final aBps = double.tryParse(a ?? '');
            if (vBps != null && vBps > 0) {
              _downloadSpeed = (vBps + (aBps ?? 0)) / 8; // bps -> bytes/s
            } else {
              _fallbackBitrateEstimate();
            }
          });
        });
      } else {
        _downloadSpeed = 0;
      }

      notifyListeners();
    });
  }

  /// 备用码率估算：当 mpv 的 video-bitrate 属性不可用时，
  /// 基于视频分辨率和帧率估算码率
  void _fallbackBitrateEstimate() {
    if (_videoWidth <= 0 || _videoHeight <= 0) {
      _downloadSpeed = 0;
      return;
    }
    final pixels = _videoWidth * _videoHeight;
    final fps = _fps > 0 ? _fps : 25.0;
    double compressionFactor;
    if (pixels >= 3840 * 2160) {
      compressionFactor = 0.04; // 4K
    } else if (pixels >= 1920 * 1080) {
      compressionFactor = 0.06; // 1080p
    } else if (pixels >= 1280 * 720) {
      compressionFactor = 0.08; // 720p
    } else {
      compressionFactor = 0.10; // SD
    }
    final estimatedBitrate = pixels * fps * compressionFactor; // bps
    _downloadSpeed = estimatedBitrate / 8.0; // bytes/s
  }

  /// 从 mpv 的 audio-params/channels 布局字符串解析声道数
  /// 例如: "stereo"→2, "5.1"→6, "7.1"→8, "mono"→1
  int _parseChannelCount(String layout) {
    if (layout.isEmpty) return 0;
    // 尝试匹配 "N.M" 或 "N" 格式的数字
    final match = RegExp(r'(\d+)').firstMatch(layout);
    if (match != null) {
      final count = int.tryParse(match.group(1)!);
      if (count != null && count > 0) return count;
    }
    // 处理命名格式
    switch (layout.toLowerCase()) {
      case 'mono':
        return 1;
      case 'stereo':
        return 2;
      case 'quad':
        return 4;
      case 'surround':
        return 5;
    }
    return 0;
  }

  void _updateHwdecFromLog(String lowerMessage) {
    String? detected;

    // e.g. "Using hardware decoding (d3d11va-copy)"
    final hwdecMatch = RegExp(r'using hardware decoding\s*\(([^)]+)\)')
        .firstMatch(lowerMessage);
    if (hwdecMatch != null) {
      detected = hwdecMatch.group(1);
    }

    // e.g. "hwdec=auto", "hwdec: d3d11va"
    final hwdecKeyMatch = RegExp(r'hwdec(?:-current)?\s*[:=]\s*([\w\-]+)')
        .firstMatch(lowerMessage);
    if (detected == null && hwdecKeyMatch != null) {
      detected = hwdecKeyMatch.group(1);
    }

    if (detected == null && lowerMessage.contains('software decoding')) {
      detected = 'no';
    }

    if (detected != null && detected.isNotEmpty && detected != _hwdecMode) {
      _hwdecMode = detected;
      notifyListeners();
    }
  }

  void _updateVoFromLog(String lowerMessage) {
    String? detected;

    // e.g. "VO: [gpu] 1920x1080"
    final voMatch =
        RegExp(r'vo:\s*\[([a-z0-9_\-]+)\]').firstMatch(lowerMessage);
    if (voMatch != null) {
      detected = voMatch.group(1);
    }

    // e.g. "Using video output driver: gpu"
    final driverMatch = RegExp(r'video output driver:\s*([a-z0-9_\-]+)')
        .firstMatch(lowerMessage);
    if (detected == null && driverMatch != null) {
      detected = driverMatch.group(1);
    }

    if (detected != null && detected.isNotEmpty && detected != _vo) {
      _vo = detected;
      notifyListeners();
    }
  }

  String _formatHwdecInfo() {
    final configured = _configuredHwdec.trim();
    final actual = _hwdecMode.trim();
    if (configured.isEmpty || configured == 'unknown') {
      return actual == 'unknown' ? '' : actual;
    }
    if (actual.isEmpty || actual == 'unknown' || actual == configured) {
      return configured;
    }
    return '$configured -> $actual';
  }

  bool _shouldTrySoftwareFallback(String error) {
    final lowerError = error.toLowerCase();
    if (!_allowSoftwareFallback) return false;
    return (lowerError.contains('codec') ||
            lowerError.contains('decoder') ||
            lowerError.contains('hwdec') ||
            lowerError.contains('mediacodec')) &&
        _retryCount < _maxRetries;
  }

  void _attemptSoftwareFallback() {
    if (!_allowSoftwareFallback) return;
    _retryCount++;
    final channelToPlay = _currentChannel;
    _initMediaKitPlayer(useSoftwareDecoding: true);
    if (channelToPlay != null) playChannel(channelToPlay);
  }

  // ============ Public API ============

  Future<void> playChannel(Channel channel,
      {bool preserveCurrentSource = false}) async {
    ServiceLocator.log
        .i('========== 开始播放频道==========', tag: 'PlayerProvider');
    ServiceLocator.log
        .i('频道: ${channel.name} (ID: ${channel.id})', tag: 'PlayerProvider');
    ServiceLocator.log.d('URL: ${channel.url}', tag: 'PlayerProvider');
    ServiceLocator.log.d('源数量 ${channel.sourceCount}', tag: 'PlayerProvider');
    final playStartTime = DateTime.now();

    _currentChannel = channel;
    _state = PlayerState.loading;
    _error = null;
    _lastErrorMessage = null; // 重置错误防抖
    _errorDisplayed = false; // 重置错误显示标记
    _retryCount = 0; // 重置重试计数
    _retryTimer?.cancel(); // 取消任何正在进行的重试
    _isAutoDetecting = false; // 取消任何正在进行的自动检测
    _noVideoFallbackAttempted = false;
    _resetDeinterlaceDetection();
    loadVolumeSettings(); // Apply volume boost settings
    // 使用 postFrameCallback 避免在构建阶段同步 notifyListeners 导致 setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    // 如果有多个源，先检测找到第一个可用的源
    if (channel.hasMultipleSources && !preserveCurrentSource) {
      ServiceLocator.log
          .i('频道有 ${channel.sourceCount} 个源，开始检测可用源', tag: 'PlayerProvider');
      final detectStartTime = DateTime.now();

      final availableSourceIndex = await _findFirstAvailableSource(channel);

      final detectTime =
          DateTime.now().difference(detectStartTime).inMilliseconds;

      if (availableSourceIndex != null) {
        channel.currentSourceIndex = availableSourceIndex;
        ServiceLocator.log.i(
            '找到可用源 ${availableSourceIndex + 1}/${channel.sourceCount}，检测耗时: ${detectTime}ms',
            tag: 'PlayerProvider');
      } else {
        ServiceLocator.log.e(
            '所有 ${channel.sourceCount} 个源都不可用，检测耗时: ${detectTime}ms',
            tag: 'PlayerProvider');
        _setError('所有 ${channel.sourceCount} 个源均不可用');
        return;
      }
    } else if (channel.hasMultipleSources) {
      channel.currentSourceIndex =
          channel.currentSourceIndex.clamp(0, channel.sourceCount - 1);
      ServiceLocator.log.d(
          'PlayerProvider: preserveCurrentSource=true, using source ${channel.currentSourceIndex + 1}/${channel.sourceCount}');
    }

    final playUrl = channel.currentUrl;
    ServiceLocator.log.d('准备播放URL: $playUrl', tag: 'PlayerProvider');

    try {
      final playerInitStartTime = DateTime.now();

      // Android TV 使用原生播放器，通过 MethodChannel 处理
      // 其他平台（包括 Android 手机）都使用 media_kit
      if (!_useNativePlayer) {
        // 解析真实播放地址（处理 302 重定向）
        ServiceLocator.log
            .i('>>> Start resolving redirect', tag: 'PlayerProvider');
        final redirectStartTime = DateTime.now();

        final realUrl =
            await ServiceLocator.redirectCache.resolveRealPlayUrl(playUrl);

        final redirectTime =
            DateTime.now().difference(redirectStartTime).inMilliseconds;
        ServiceLocator.log
            .i('>>> 302重定向解析完成，耗时: ${redirectTime}ms', tag: 'PlayerProvider');
        ServiceLocator.log.d('>>> 使用播放地址: $realUrl', tag: 'PlayerProvider');

        // 开始播放
        ServiceLocator.log
            .i('>>> Start initializing player', tag: 'PlayerProvider');
        final playStartTime = DateTime.now();
        // 代际计数器已在 _resetDeinterlaceDetection() 中递增，确保旧回调不影响新流
        await _applyDeinterlaceFilter();
        await _mediaKitPlayer?.open(_createMedia(realUrl));

        final playTime =
            DateTime.now().difference(playStartTime).inMilliseconds;
        ServiceLocator.log
            .i('>>> 播放器初始化完成，耗时: ${playTime}ms', tag: 'PlayerProvider');
        _state = PlayerState.playing;
        notifyListeners();
        _scheduleNoVideoFallbackIfNeeded();
      }

      // 记录观看历史
      final channelId = channel.id;
      final playlistId = channel.playlistId;
      if (channelId != null) {
        await ServiceLocator.watchHistory
            .addWatchHistory(channelId, playlistId);
      }

      final playerInitTime =
          DateTime.now().difference(playerInitStartTime).inMilliseconds;
      final totalTime = DateTime.now().difference(playStartTime).inMilliseconds;
      ServiceLocator.log.i(
          '>>> 播放流程总耗时: ${totalTime}ms (播放器初始化: ${playerInitTime}ms)',
          tag: 'PlayerProvider');
      ServiceLocator.log.i('========== 频道播放总耗时: ${totalTime}ms ==========',
          tag: 'PlayerProvider');
    } catch (e) {
      ServiceLocator.log.e('播放频道失败', tag: 'PlayerProvider', error: e);
      _setError('Failed to play channel: $e');
      return;
    }
  }

  Future<void> reinitializePlayer({required String bufferStrength}) async {
    if (_useNativePlayer) return;
    final channelToPlay = _currentChannel;
    _state = PlayerState.loading;
    notifyListeners();
    _initMediaKitPlayer(bufferStrength: bufferStrength);
    if (channelToPlay != null) {
      await playChannel(channelToPlay);
    }
  }

  /// 查找第一个可用的源
  Future<int?> _findFirstAvailableSource(Channel channel) async {
    ServiceLocator.log
        .d('开始检测第${channel.sourceCount} 个源', tag: 'PlayerProvider');
    final testService = ChannelTestService();

    for (int i = 0; i < channel.sourceCount; i++) {
      // 更新UI显示当前检测的源
      channel.currentSourceIndex = i;
      notifyListeners();

      // 创建临时频道对象用于测试
      final tempChannel = Channel(
        id: channel.id,
        name: channel.name,
        url: channel.sources[i],
        groupName: channel.groupName,
        logoUrl: channel.logoUrl,
        sources: [channel.sources[i]], // 只测试当前源
        playlistId: channel.playlistId,
      );

      ServiceLocator.log
          .d('检测源 ${i + 1}/${channel.sourceCount}', tag: 'PlayerProvider');
      final testStartTime = DateTime.now();

      final result = await testService.testChannel(tempChannel);
      final testTime = DateTime.now().difference(testStartTime).inMilliseconds;

      if (result.isAvailable) {
        ServiceLocator.log.i(
            '源${i + 1} 可用，响应时间: ${result.responseTime}ms，检测耗时: ${testTime}ms',
            tag: 'PlayerProvider');
        return i;
      } else {
        ServiceLocator.log.w(
            '✗ 源 ${i + 1} 不可用: ${result.error}，检测耗时: ${testTime}ms',
            tag: 'PlayerProvider');
      }
    }

    ServiceLocator.log
        .e('所有${channel.sourceCount} 个源都不可用', tag: 'PlayerProvider');
    return null; // 所有源都不可用
  }

  Future<void> playUrl(String url, {String? name}) async {
    // Android TV 使用原生播放器，不支持此方法
    if (_useNativePlayer) {
      ServiceLocator.log
          .w('playUrl: Android TV 使用原生播放器，不支持此方法', tag: 'PlayerProvider');
      return;
    }

    final startTime = DateTime.now();
    _state = PlayerState.loading;
    _error = null;
    _lastErrorMessage = null; // 重置错误防抖
    _errorDisplayed = false; // 重置错误显示标记
    _noVideoFallbackAttempted = false;
    _resetDeinterlaceDetection();
    loadVolumeSettings(); // Apply volume boost settings
    notifyListeners();

    try {
      // 解析真实播放地址（处理 302 重定向）
      ServiceLocator.log
          .i('>>> Start resolving redirect', tag: 'PlayerProvider');
      final redirectStartTime = DateTime.now();

      final realUrl =
          await ServiceLocator.redirectCache.resolveRealPlayUrl(url);

      final redirectTime =
          DateTime.now().difference(redirectStartTime).inMilliseconds;
      ServiceLocator.log
          .i('>>> 302重定向解析完成，耗时: ${redirectTime}ms', tag: 'PlayerProvider');
      ServiceLocator.log.d('>>> 使用播放地址: $realUrl', tag: 'PlayerProvider');

      // 开始播放
      ServiceLocator.log
          .i('>>> Start initializing player', tag: 'PlayerProvider');
      final playStartTime = DateTime.now();
      // 代际计数器已在 _resetDeinterlaceDetection() 中递增，确保旧回调不影响新流
      await _applyDeinterlaceFilter();
      await _mediaKitPlayer?.open(_createMedia(realUrl));

      final playTime = DateTime.now().difference(playStartTime).inMilliseconds;
      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log
          .i('>>> 播放器初始化完成，耗时: ${playTime}ms', tag: 'PlayerProvider');
      ServiceLocator.log
          .i('>>> 播放流程总耗时: ${totalTime}ms', tag: 'PlayerProvider');

      _state = PlayerState.playing;
      _scheduleNoVideoFallbackIfNeeded();
    } catch (e) {
      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log
          .e('>>> 播放失败 (${totalTime}ms): $e', tag: 'PlayerProvider');
      _setError('Failed to play: $e');
      return;
    }
    notifyListeners();
  }

  void togglePlayPause() {
    if (_useNativePlayer) return; // TV 端由原生播放器处理
    _mediaKitPlayer?.playOrPause();
  }

  void pause() {
    if (_useNativePlayer) return; // TV 端由原生播放器处理
    _mediaKitPlayer?.pause();
  }

  void play() {
    if (_useNativePlayer) return; // TV 端由原生播放器处理
    _mediaKitPlayer?.play();
  }

  Future<void> stop({bool silent = false}) async {
    _state = PlayerState.idle;
    _error = null;
    _overrideDuration = null; // Clear override duration
    _retryCount = 0;
    _retryTimer?.cancel();

    // 取消可能正在进行的检测
    _isAutoDetecting = false;

    if (_mediaKitPlayer != null) {
      _mediaKitPlayer?.stop();
    }
    _state = PlayerState.idle;
    _currentChannel = null;

    if (!silent) {
      notifyListeners();
    }
  }

  void seek(Duration position) {
    if (_useNativePlayer) return; // TV 端由原生播放器处理
    _mediaKitPlayer?.seek(position);
  }

  void seekForward(int seconds) {
    seek(_position + Duration(seconds: seconds));
  }

  void seekBackward(int seconds) {
    final newPos = _position - Duration(seconds: seconds);
    seek(newPos.isNegative ? Duration.zero : newPos);
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _applyVolume();
    if (_volume > 0) _isMuted = false;
    notifyListeners();
  }

  double _volumeBeforeMute = 1.0; // 保存静音前的音量

  void toggleMute() {
    if (!_isMuted) {
      // 静音前保存当前音量
      _volumeBeforeMute = _volume > 0 ? _volume : 1.0;
    }
    _isMuted = !_isMuted;
    if (!_isMuted && _volume == 0) {
      // 取消静音时如果音量为0，恢复到之前的音量
      _volume = _volumeBeforeMute;
    }
    _applyVolume();
    notifyListeners();
  }

  /// Apply volume boost from settings (in dB)
  void setVolumeBoost(int db) {
    _volumeBoostDb = db.clamp(-20, 20);
    _applyVolume();
    notifyListeners();
  }

  /// Load volume settings from preferences
  void loadVolumeSettings() {
    final prefs = ServiceLocator.prefs;
    // 音量增强独立于音量标准化，最终加载
    _volumeBoostDb = prefs.getInt('volume_boost') ?? 0;
    _applyVolume();
  }

  /// Calculate and apply the effective volume with boost
  void _applyVolume() {
    if (_useNativePlayer) return; // TV 端由原生播放器处理

    if (_isMuted) {
      _mediaKitPlayer?.setVolume(0);
      return;
    }

    // Convert dB to linear multiplier: multiplier = 10^(dB/20)
    final multiplier = math.pow(10, _volumeBoostDb / 20.0);
    final effectiveVolume =
        (_volume * multiplier).clamp(0.0, 2.0); // Allow up to 2x volume

    // media_kit uses 0-100 scale, but can go higher for boost
    _mediaKitPlayer?.setVolume(effectiveVolume * 100);
  }

  void setPlaybackSpeed(double speed) {
    if (_useNativePlayer) return; // TV 端由原生播放器处理
    _playbackSpeed = speed;
    _mediaKitPlayer?.setRate(speed);
    notifyListeners();
  }

  void toggleFullscreen() {
    _isFullscreen = !_isFullscreen;
    notifyListeners();
  }

  void setFullscreen(bool fullscreen) {
    _isFullscreen = fullscreen;
    notifyListeners();
  }

  void setControlsVisible(bool visible) {
    _controlsVisible = visible;
    notifyListeners();
  }

  void toggleControls() {
    _controlsVisible = !_controlsVisible;
    notifyListeners();
  }

  void playNext(List<Channel> channels) {
    if (_currentChannel == null || channels.isEmpty) return;
    final idx = channels.indexWhere((c) => c.id == _currentChannel!.id);
    if (idx == -1 || idx >= channels.length - 1) return;
    playChannel(channels[idx + 1]);
  }

  void playPrevious(List<Channel> channels) {
    if (_currentChannel == null || channels.isEmpty) return;
    final idx = channels.indexWhere((c) => c.id == _currentChannel!.id);
    if (idx <= 0) return;
    playChannel(channels[idx - 1]);
  }

  /// Switch to next source for current channel (if has multiple sources)
  void switchToNextSource() {
    if (_currentChannel == null || !_currentChannel!.hasMultipleSources) return;

    // 取消任何正在进行的自动检测
    _isAutoDetecting = false;
    _retryTimer?.cancel();

    final newIndex = (_currentChannel!.currentSourceIndex + 1) %
        _currentChannel!.sourceCount;
    _currentChannel!.currentSourceIndex = newIndex;

    ServiceLocator.log.d(
        'PlayerProvider: 手动切换到源 ${newIndex + 1}/${_currentChannel!.sourceCount}');

    // 只有在非自动切换时才重置（手动切换时重置）
    if (!_isAutoSwitching) {
      _retryCount = 0;
      ServiceLocator.log
          .d('PlayerProvider: Manual source switch, reset retry state');
    }

    // Play the new source
    _playCurrentSource();
  }

  /// Switch to previous source for current channel (if has multiple sources)
  void switchToPreviousSource() {
    if (_currentChannel == null || !_currentChannel!.hasMultipleSources) return;

    // 取消任何正在进行的自动检测
    _isAutoDetecting = false;
    _retryTimer?.cancel();

    final newIndex = (_currentChannel!.currentSourceIndex -
            1 +
            _currentChannel!.sourceCount) %
        _currentChannel!.sourceCount;
    _currentChannel!.currentSourceIndex = newIndex;

    ServiceLocator.log.d(
        'PlayerProvider: 手动切换到源 ${newIndex + 1}/${_currentChannel!.sourceCount}');

    // 只有在非自动切换时才重置（手动切换时重置）
    if (!_isAutoSwitching) {
      _retryCount = 0;
      ServiceLocator.log
          .d('PlayerProvider: Manual source switch, reset retry state');
    }

    // Play the new source
    _playCurrentSource();
  }

  /// Play the current source of the current channel
  Future<void> _playCurrentSource() async {
    if (_currentChannel == null) return;

    // 记录初始配置
    ServiceLocator.log.d('开始播放频道源', tag: 'PlayerProvider');
    ServiceLocator.log.d(
        '频道: ${_currentChannel!.name}, 源索引 ${_currentChannel!.currentSourceIndex}/${_currentChannel!.sourceCount}',
        tag: 'PlayerProvider');

    // 检测当前源是否可用
    final testService = ChannelTestService();
    final tempChannel = Channel(
      id: _currentChannel!.id,
      name: _currentChannel!.name,
      url: _currentChannel!.currentUrl,
      groupName: _currentChannel!.groupName,
      logoUrl: _currentChannel!.logoUrl,
      sources: [_currentChannel!.currentUrl],
      playlistId: _currentChannel!.playlistId,
    );

    ServiceLocator.log
        .i('检测源可用性: ${_currentChannel!.currentUrl}', tag: 'PlayerProvider');

    final result = await testService.testChannel(tempChannel);

    if (!result.isAvailable) {
      ServiceLocator.log.w('源不可用: ${result.error}', tag: 'PlayerProvider');
      _setError('源不可用: ${result.error}');
      return;
    }

    ServiceLocator.log
        .i('源可用，响应时间: ${result.responseTime}ms', tag: 'PlayerProvider');

    final url = _currentChannel!.currentUrl;
    final startTime = DateTime.now();

    _state = PlayerState.loading;
    _error = null;
    _lastErrorMessage = null;
    _errorDisplayed = false;
    _noVideoFallbackAttempted = false;
    notifyListeners();

    try {
      if (!_useNativePlayer) {
        // 解析真实播放地址（处理 302 重定向）
        ServiceLocator.log.i('>>> Source switch: start resolving redirect',
            tag: 'PlayerProvider');
        final redirectStartTime = DateTime.now();

        final realUrl =
            await ServiceLocator.redirectCache.resolveRealPlayUrl(url);

        final redirectTime =
            DateTime.now().difference(redirectStartTime).inMilliseconds;
        ServiceLocator.log.i('>>> 切换源: 302重定向解析完成，耗时: ${redirectTime}ms',
            tag: 'PlayerProvider');
        ServiceLocator.log
            .d('>>> 切换源: 使用播放地址: $realUrl', tag: 'PlayerProvider');

        final playStartTime = DateTime.now();
        // 代际计数器已在 _resetDeinterlaceDetection() 中递增，确保旧回调不影响新流
        await _applyDeinterlaceFilter();
        await _mediaKitPlayer?.open(_createMedia(realUrl));

        final playTime =
            DateTime.now().difference(playStartTime).inMilliseconds;
        final totalTime = DateTime.now().difference(startTime).inMilliseconds;
        ServiceLocator.log
            .i('>>> 切换源: 播放器初始化完成，耗时: ${playTime}ms', tag: 'PlayerProvider');
        ServiceLocator.log
            .i('>>> 切换源: 总耗时: ${totalTime}ms', tag: 'PlayerProvider');

        _state = PlayerState.playing;
        _scheduleNoVideoFallbackIfNeeded();
      }
      ServiceLocator.log.i('播放成功', tag: 'PlayerProvider');
    } catch (e) {
      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      ServiceLocator.log
          .e('播放失败 (${totalTime}ms)', tag: 'PlayerProvider', error: e);
      _setError('Failed to play source: $e');
      return;
    }
    notifyListeners();
  }

  /// Get current source index (1-based for display)
  int get currentSourceIndex => (_currentChannel?.currentSourceIndex ?? 0) + 1;

  /// Get total source count
  int get sourceCount => _currentChannel?.sourceCount ?? 1;

  /// Set current channel without starting playback (for native player coordination)
  void setCurrentChannelOnly(Channel channel) {
    _currentChannel = channel;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debugInfoTimer?.cancel();
    _retryTimer?.cancel();
    _mediaKitPlayer?.dispose();
    super.dispose();
  }

  void _scheduleNoVideoFallbackIfNeeded() {
    if (_useNativePlayer) return;
    if (!Platform.isWindows) return;
    if (_isSoftwareDecoding) return;
    if (!_allowSoftwareFallback) return;
    if (_noVideoFallbackAttempted) return;

    _noVideoFallbackAttempted = true;
    Future.delayed(const Duration(seconds: 3), () {
      if (_isDisposed) return;
      // 若已播放但仍无画面（宽度为0），尝试解码回调
      if (_state == PlayerState.playing &&
          _videoWidth == 0 &&
          _videoHeight == 0) {
        ServiceLocator.log
            .w('PlayerProvider: 音频帧变慢时画面卡顿，尝试软件回退', tag: 'PlayerProvider');
        _attemptSoftwareFallback();
      }
    });
  }
}
