import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import '../../../core/models/channel.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/log_service.dart';
import '../../settings/providers/settings_provider.dart';

/// 单个屏幕的播放器状态
class ScreenPlayerState {
  Player? player;
  VideoController? videoController;
  Channel? channel;
  bool isPlaying = false;
  bool isLoading = false;
  String? error;
  bool isSoftwareDecoding = false;
  bool softwareFallbackAttempted = false;
  String hwdecMode = 'auto-safe';
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  
  // 视频信息
  int videoWidth = 0;
  int videoHeight = 0;
  int bitrate = 0;
  double fps = 0;
  double networkSpeed = 0;

  // 去交错检测状态（按播放器独立跟踪）
  StreamSubscription<VideoParams>? videoParamsSubscription;
  bool deinterlaceConfigured = false;
  bool initialHwdecSet = false;
  int deinterlaceGeneration = 0; // 代际计数器，用于检测过时的 videoParams 回调
  
  ScreenPlayerState();
  
  Future<void> dispose() async {
    // 取消去交错监听
    videoParamsSubscription?.cancel();
    videoParamsSubscription = null;
    // 先停止播放，再释放资源
    if (player != null) {
      await player!.stop();
      await player!.dispose();
    }
    player = null;
    videoController = null;
    channel = null;
    isPlaying = false;
  }
}

class MultiScreenProvider extends ChangeNotifier {
  // 4个屏幕的播放器状态
  final List<ScreenPlayerState> _screens = List.generate(4, (_) => ScreenPlayerState());
  int _activeScreenIndex = 0;
  bool _isMultiScreenMode = false;
  String _videoOutput = 'auto';
  String _windowsHwdecMode = 'auto-safe';
  String _d3d11vppMode = 'bob';
  bool _allowSoftwareFallback = true;
  String _decodingMode = 'auto';
  String _bufferStrength = 'fast';
  
  // 音量设置
  double _volume = 1.0;
  int _volumeBoostDb = 0;

  List<ScreenPlayerState> get screens => _screens;
  int get activeScreenIndex => _activeScreenIndex;
  bool get isMultiScreenMode => _isMultiScreenMode;
  double get volume => _volume;
  ScreenPlayerState get activeScreen => _screens[_activeScreenIndex];

  // 获取指定屏幕的状态
  ScreenPlayerState getScreen(int index) {
    if (index >= 0 && index < 4) {
      return _screens[index];
    }
    return _screens[0];
  }
  
  // 设置音量和音量增强
  void setVolumeSettings(double volume, int volumeBoostDb) {
    _volume = volume;
    _volumeBoostDb = volumeBoostDb;
    _applyVolumeToActiveScreen();
  }

  void updatePlaybackConfig({
    required String videoOutput,
    required String windowsHwdecMode,
    required String d3d11vppMode,
    required bool allowSoftwareFallback,
    required String decodingMode,
    required String bufferStrength,
  }) {
    _videoOutput = videoOutput;
    _windowsHwdecMode = windowsHwdecMode;
    _d3d11vppMode = d3d11vppMode;
    _allowSoftwareFallback = allowSoftwareFallback;
    _decodingMode = decodingMode;
    _bufferStrength = bufferStrength;
  }

  Future<void> reinitializePlayers({
    required String videoOutput,
    required String windowsHwdecMode,
    required String d3d11vppMode,
    required bool allowSoftwareFallback,
    required String decodingMode,
    required String bufferStrength,
  }) async {
    updatePlaybackConfig(
      videoOutput: videoOutput,
      windowsHwdecMode: windowsHwdecMode,
      d3d11vppMode: d3d11vppMode,
      allowSoftwareFallback: allowSoftwareFallback,
      decodingMode: decodingMode,
      bufferStrength: bufferStrength,
    );

    final channels = List<Channel?>.from(_screens.map((s) => s.channel));
    for (int i = 0; i < _screens.length; i++) {
      await _disposeScreenPlayer(i);
    }
    for (int i = 0; i < channels.length; i++) {
      if (channels[i] != null) {
        await playChannelOnScreen(i, channels[i]!, skipHistory: true);
      }
    }
  }
  
  // 计算有效音量（包含增强）
  double _getEffectiveVolume() {
    if (_volumeBoostDb == 0) {
      return _volume * 100;
    }
    // 将 dB 转换为线性增益
    final boostFactor = math.pow(10, _volumeBoostDb / 20);
    return (_volume * boostFactor * 100).clamp(0, 200);
  }
  
  // 应用音量到活动屏幕
  void _applyVolumeToActiveScreen() {
    final screen = _screens[_activeScreenIndex];
    if (screen.player != null) {
      screen.player!.setVolume(_getEffectiveVolume());
    }
  }

  // 设置活动屏幕
  void setActiveScreen(int index) {
    if (index >= 0 && index < 4 && _activeScreenIndex != index) {
      // 静音之前的活动屏幕
      final oldScreen = _screens[_activeScreenIndex];
      if (oldScreen.player != null) {
        oldScreen.player!.setVolume(0);
      }
      
      _activeScreenIndex = index;
      
      // 取消静音新的活动屏幕（使用有效音量，包含音量增强）
      final newScreen = _screens[_activeScreenIndex];
      if (newScreen.player != null) {
        newScreen.player!.setVolume(_getEffectiveVolume());
      }
      
      ServiceLocator.log.d('MultiScreenProvider: Active screen changed to $index');
      notifyListeners();
    }
  }

  // 启用/禁用分屏模式
  void setMultiScreenMode(bool enabled) {
    _isMultiScreenMode = enabled;
    if (!enabled) {
      // 禁用分屏模式时，停止所有非活动屏幕的播放
      for (int i = 0; i < 4; i++) {
        if (i != _activeScreenIndex) {
          stopScreen(i);
        }
      }
    }
    notifyListeners();
  }

  // 在指定屏幕播放频道
  Future<void> playChannelOnScreen(int screenIndex, Channel channel,
      {bool skipHistory = false}) async {
    if (screenIndex < 0 || screenIndex >= 4) return;
    
    // 使用 currentUrl 而不是 url，以保留当前选择的源索引
    final playUrl = channel.currentUrl;
    ServiceLocator.log.d('MultiScreenProvider: playChannelOnScreen - screenIndex=$screenIndex, channel=${channel.name}, sourceIndex=${channel.currentSourceIndex}, url=$playUrl, activeScreen=$_activeScreenIndex');
    
    final screen = _screens[screenIndex];
    
    // 如果已经在播放相同的频道和相同的源，不重复播放
    if (screen.channel?.currentUrl == playUrl && screen.isPlaying) {
      ServiceLocator.log.d('MultiScreenProvider: Already playing same channel and source, skipping');
      return;
    }
    
    // Windows端分屏模式也需要记录观看历史
    if (!skipHistory && channel.id != null) {
      await ServiceLocator.watchHistory
          .addWatchHistory(channel.id!, channel.playlistId);
      ServiceLocator.log.d('MultiScreenProvider: Recorded watch history for channel ${channel.name} (Windows multi-screen)');
    }
    
    screen.isLoading = true;
    screen.error = null;
    screen.channel = channel;
    screen.position = Duration.zero;
    screen.duration = Duration.zero;
    notifyListeners();
    
    try {
      // 如果播放器不存在，创建新的播放器
      if (screen.player == null) {
        ServiceLocator.log.d('MultiScreenProvider: Creating new player for screen $screenIndex');
        _createPlayerForScreen(screenIndex, useSoftwareDecoding: false);
        // 为新播放器挂接流监听（首次创建时）
        _setupPlayerListeners(screenIndex, screen);
      }
      
      // 设置音量（只有活动屏幕有声音，使用有效音量包含音量增强）
      _applyVolumeToScreen(screenIndex);
      
      // 解析真实播放地址（处理302重定向）
      ServiceLocator.log.d('MultiScreenProvider: >>> 屏幕$screenIndex 开始解析302重定向');
      final redirectStartTime = DateTime.now();
      
      final realUrl = await ServiceLocator.redirectCache.resolveRealPlayUrl(playUrl);
      
      final redirectTime = DateTime.now().difference(redirectStartTime).inMilliseconds;
      ServiceLocator.log.d('MultiScreenProvider: >>> 屏幕$screenIndex 302重定向解析完成，耗时: ${redirectTime}ms');
      ServiceLocator.log.d('MultiScreenProvider: >>> 屏幕$screenIndex 使用播放地址: $realUrl');
      
      // 播放频道（使用解析后的真实URL）
      ServiceLocator.log.d('MultiScreenProvider: Opening media for screen $screenIndex: $realUrl');
      final playStartTime = DateTime.now();
      
      final userAgent = ServiceLocator.settings?.userAgent ?? SettingsProvider.defaultUserAgent;
      ServiceLocator.log.d('MultiScreenProvider: 屏幕$screenIndex User-Agent: $userAgent');

      // 重置去交错检测，为新流准备新的订阅。不重置 initialHwdecSet，
      // 避免每次换台同步阶段重新设置 hwdec 触发 mpv 视频链初始化导致的延迟。
      // 代际计数器确保旧的 videoParams 回调不会锁死新流的 guard。
      screen.deinterlaceGeneration++; // 递增代际，使正在执行的旧回调失效
      screen.videoParamsSubscription?.cancel();
      screen.videoParamsSubscription = null;
      screen.deinterlaceConfigured = false;
      await _applyDeinterlaceFilter(screen.player!);

      await screen.player!.open(Media(realUrl, httpHeaders: {'User-Agent': userAgent}));
      
      final playTime = DateTime.now().difference(playStartTime).inMilliseconds;
      ServiceLocator.log.d('MultiScreenProvider: >>> 屏幕$screenIndex 播放器初始化完成，耗时: ${playTime}ms');
      
      // 播放开始后再次确保音量正确
      _applyVolumeToScreen(screenIndex);
      
      screen.isLoading = false;
      ServiceLocator.log.d('MultiScreenProvider: Screen $screenIndex started playing');
      notifyListeners();
    } catch (e) {
      ServiceLocator.log.d('MultiScreenProvider: Screen $screenIndex playback error: $e');
      final switched =
          await _tryNextSourceOnError(screenIndex, screen, e.toString());
      if (switched) return;
      screen.error = e.toString();
      screen.isLoading = false;
      notifyListeners();
    }
  }

  /// 为指定屏幕的播放器挂接流监听（播放状态/尺寸/进度/日志/错误/缓冲）。
  ///
  /// 首次创建播放器与软件解码回退替换播放器后都必须调用，否则新的播放器
  /// 的状态变化（尤其是错误与缓冲）无法被捕获，UI 不会更新、错误会静默。
  void _setupPlayerListeners(int screenIndex, ScreenPlayerState screen) {
    final player = screen.player;
    if (player == null) return;

    // 监听播放状态
    player.stream.playing.listen((playing) {
      ServiceLocator.log.d('MultiScreenProvider: Screen $screenIndex playing=$playing');
      screen.isPlaying = playing;
      // 播放开始后确保音量正确（使用当前的 _activeScreenIndex）
      if (playing) {
        _applyVolumeToScreen(screenIndex);
      }
      notifyListeners();
    });

    // 监听视频尺寸
    player.stream.width.listen((width) {
      screen.videoWidth = width ?? 0;
      notifyListeners();
    });

    player.stream.height.listen((height) {
      screen.videoHeight = height ?? 0;
      notifyListeners();
    });

    player.stream.position.listen((position) {
      screen.position = position;
      notifyListeners();
    });

    player.stream.duration.listen((duration) {
      screen.duration = duration;
      notifyListeners();
    });

    // 监听 mpv 日志，过滤冗余 FFmpeg 输出
    player.stream.log.listen((log) {
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
        ServiceLocator.log.d(
            'MultiScreen MPV log [screen $screenIndex]: ${log.text}',
            tag: 'MultiScreenProvider');
      }
    });

    // 监听错误
    player.stream.error.listen((error) async {
      if (error.isNotEmpty) {
        ServiceLocator.log.d('MultiScreenProvider: Screen $screenIndex error=$error');
        if (_shouldTrySoftwareFallback(error, screen)) {
          _attemptSoftwareFallback(screenIndex);
          return;
        }
        final switched =
            await _tryNextSourceOnError(screenIndex, screen, error);
        if (switched) return;
        screen.error = error;
        screen.isLoading = false;
        notifyListeners();
      }
    });

    // 监听缓冲状态
    player.stream.buffering.listen((buffering) {
      screen.isLoading = buffering;
      notifyListeners();
    });
  }

  Future<void> _createPlayerForScreen(int screenIndex, {required bool useSoftwareDecoding}) async {
    final screen = _screens[screenIndex];
    screen.player?.dispose();

    final bufferSize = switch (_bufferStrength) {
      'fast' => 32 * 1024 * 1024,
      'balanced' => 64 * 1024 * 1024,
      'stable' => 128 * 1024 * 1024,
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

    final player = Player(
      configuration: PlayerConfiguration(
        bufferSize: bufferSize,
        vo: vo,
      ),
    );
    screen.player = player;

    final effectiveSoftware = useSoftwareDecoding || _decodingMode == 'software';
    String? hwdecMode;
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

    screen.hwdecMode = hwdecMode;

    screen.videoController = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        hwdec: hwdecMode,
        enableHardwareAcceleration: !effectiveSoftware,
      ),
    );
    screen.isSoftwareDecoding = effectiveSoftware;
    screen.softwareFallbackAttempted = effectiveSoftware;

    // VideoController 创建后会强制设 hwdec=auto，在此覆盖去交错参数
    // 必须在 open() 之前调用，否则 hwdec=auto 会绕过 vf 滤镜链
    // 重置 initialHwdecSet 确保新播放器的 hwdec 被正确设置
    screen.initialHwdecSet = false;
    screen.videoParamsSubscription?.cancel();
    screen.videoParamsSubscription = null;
    screen.deinterlaceConfigured = false;
    await _applyDeinterlaceFilter(player);
  }

  /// 安全调用 setProperty，单个失败不影响其他调用
  /// 返回 true 表示成功，false 表示失败
  Future<bool> _safeSetProperty(
      Player player, String property, String value, String label) async {
    try {
      final nativePlayer = player.platform as dynamic;
      await nativePlayer.setProperty(property, value);
      return true;
    } catch (e) {
      ServiceLocator.log.d('MultiScreenProvider: 设置 $label 失败: $e');
      return false;
    }
  }

  /// 安全读取 getProperty，失败返回 null
  Future<String?> _safeGetProperty(Player player, String property, String label) async {
    try {
      final nativePlayer = player.platform as dynamic;
      return await nativePlayer.getProperty(property);
    } catch (e) {
      ServiceLocator.log.d('MultiScreenProvider: 读取 $label 失败: $e');
      return null;
    }
  }

  /// 验证滤镜链/去交错是否真正生效（修复验证盲区）
  Future<bool> _verifyFilterChainActive(Player player, String label) async {
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

    final logSub = player.stream.log.listen((log) => checkFailure(log.text));
    final errSub = player.stream.error.listen((err) {
      if (err.isNotEmpty) checkFailure(err);
    });
    final failed = await failureSignaled.future.timeout(
      const Duration(milliseconds: 350),
      onTimeout: () => false,
    );
    await logSub.cancel();
    await errSub.cancel();
    if (failed) {
      ServiceLocator.log.d('MultiScreenProvider: 滤镜链验证失败($label): 检测到 mpv 滤镜配置错误');
    }
    return !failed;
  }

  /// 返回用户配置的 hwdec 模式，考虑软解码设置
  String _getConfiguredHwdecMode() {
    if (_decodingMode == 'software') return 'no';
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

  /// 应用去交错（反隔行）配置（多屏版）
  ///
  /// 时序分两阶段，同步 player_provider 的逻辑：
  ///   1. 同步阶段（open() 之前）：
  ///      - 设置公共参数 video-sync / framedrop
  ///      - 设置 deinterlace=no, vf=``（清除旧滤镜残留）
  ///      - 仅在首次创建播放器时设置 hwdec（通过 initialHwdecSet 控制）
  ///   2. 异步阶段（videoParams 回调）：
  ///      - 根据源类型做增量调整：
  ///        - 1080i: 切换 hwdec=d3d11va-copy + 尝试软件 vf 滤镜
  ///        - 逐行源: 重置 hwdec 为用户配置模式，清除上一流可能残留的 d3d11va-copy
  ///      - 部分场景（软件滤镜失败）回退硬件去交错
  ///
  /// 注意：每次切换频道前必须递增代际计数器，确保旧的 videoParams 异步回调
  /// 不会干扰新流的配置。initialHwdecSet 仅在创建新播放器时重置，不随换台重置，
  /// 避免不必要的 hwdec 设置触发 mpv 视频链初始化延迟。
  Future<void> _applyDeinterlaceFilter(Player player) async {
    if (!Platform.isWindows) return;
    final prefs = ServiceLocator.prefs;
    final enabled = prefs.getBool('deinterlace_enabled') ?? true;

    // 公共参数：所有源均使用 display-resample 同步
    await _safeSetProperty(player, 'video-sync', 'display-resample', 'video-sync');
    await _safeSetProperty(player, 'framedrop', 'vo', 'framedrop');

    // 允许 RTSP 协议：media_kit 默认 protocol-whitelist 不含 rtsp，
    // 会导致 avformat_open_input() 失败并报 "Protocol 'rtsp' not on whitelist"
    // 覆盖为包含 rtsp（及底层 udp/rtp/tcp）的安全白名单
    await _safeSetProperty(
        player,
        'protocol-whitelist',
        'udp,rtp,rtsp,tcp,tls,data,file,http,https,crypto',
        'protocol-whitelist');

    // 查找该播放器对应的屏幕状态
    final screen = _screens.where((s) => s.player == player).firstOrNull;
    if (screen == null) return;

    // ═══════════════════════════════════════════════
    // 同步阶段（open() 之前）：设置解码器启动参数
    // ═══════════════════════════════════════════════
    if (enabled) {
      // 启用去交错：使用用户配置的 hwdec 模式（如 auto-safe、auto-copy 等）
      // - 不使用硬编码 d3d11va-copy：某些 HEVC 4K 流在 d3d11va-copy 下解码失败（PPS id out of range）
      // - 异步 videoParams 回调确认是 1080i 后，才会切换为 d3d11va-copy 以支持软件 vf 滤镜
      // - 对逐行 4K 源：保持用户配置的 hwdec，避免解码器不兼容
      // hwdec 只在首次设置，避免 open() 后重复设置触发解码器重建
      if (!screen.initialHwdecSet) {
        await _safeSetProperty(player, 'hwdec', _getConfiguredHwdecMode(), 'hwdec');
        screen.initialHwdecSet = true;
      }
      await _safeSetProperty(player, 'deinterlace', 'no', 'deinterlace');
      await _safeSetProperty(player, 'vf', '', 'clear_vf');
    } else {
      // 禁用去交错：使用用户配置的 hwdec
      await _safeSetProperty(player, 'deinterlace', 'no', 'deinterlace');
      await _safeSetProperty(player, 'vf', '', 'clear_vf');
      if (!screen.initialHwdecSet) {
        await _safeSetProperty(player, 'hwdec', _getConfiguredHwdecMode(), 'hwdec');
        screen.initialHwdecSet = true;
      }
      // 取消该播放器的订阅
      screen.videoParamsSubscription?.cancel();
      screen.videoParamsSubscription = null;
      ServiceLocator.log.d('MultiScreenProvider: 去交错已禁用');
      return;
    }

    // ═══════════════════════════════════════════════
    // 异步阶段（open() 之后）：videoParams 流回调，增量调整
    // ═══════════════════════════════════════════════
    // 仅当尚未设置监听器时设置（避免重复订阅）
    if (screen.videoParamsSubscription == null) {
      screen.deinterlaceConfigured = false;
      screen.videoParamsSubscription = player.stream.videoParams.listen((params) async {
        // 捕获当前代际，用于检测过时的回调
        final capturedGeneration = screen.deinterlaceGeneration;
        // 等待有效数据（w > 0 && h > 0），且防重入
        if (screen.deinterlaceConfigured || params.w == null || params.w! <= 0) return;

        // 补读 video-frame-info/interlaced — VideoParams 不含此字段
        final interlaced = await _safeGetProperty(player, 'video-frame-info/interlaced', 'interlaced');
        // 补读 estimated-vf-fps 辅助判定
        final vfFpsStr = await _safeGetProperty(player, 'estimated-vf-fps', 'vf-fps');
        final vfFps = double.tryParse(vfFpsStr ?? '') ?? 0;

        // 读取源端实际色彩空间，用于动态 HDR/SDR 判定
        // 注意：色彩空间信息（gamma/primaries）可能延迟就绪，需先检查再设置 guard
        final srcGamma = await _safeGetProperty(player, 'video-params/gamma', 'gamma');
        final srcPrimaries = await _safeGetProperty(player, 'video-params/primaries', 'primaries');

        // 如果 HDR 元数据尚未就绪，不设置 guard 标志，等待下次 videoParams 事件重试
        if (srcGamma == null || srcGamma.isEmpty || srcPrimaries == null || srcPrimaries.isEmpty) {
          ServiceLocator.log.d(
              'MultiScreenProvider: 色彩空间信息尚未就绪 (gamma=$srcGamma, primaries=$srcPrimaries)，延迟到下次 videoParams 事件配置');
          return;
        }

        // 检查代际：如果在此期间 playChannelOnScreen() 被调用（快速切换频道），
        // 当前回调属于旧流，不应再设置 guard 或配置参数，让新流的回调来处理
        if (capturedGeneration != screen.deinterlaceGeneration) {
          ServiceLocator.log.d('MultiScreenProvider: videoParams 回调已过时（代际变化），忽略');
          return;
        }

        screen.deinterlaceConfigured = true;

        final sigPeak = await _safeGetProperty(player, 'video-params/sig-peak', 'sig-peak');

        // 读取 codec 用于预设规则
        final codec = await _safeGetProperty(player, 'video-params/codec', 'codec');

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
            await _safeSetProperty(player, 'hdr-compute-peak', 'yes', 'hdr-compute-peak');
            ServiceLocator.log.i(
                'MultiScreenProvider: HDR 源(HLG): mpv 默认 HLG→SDR 转换 (gamma=$srcGamma, primaries=$srcPrimaries)');
          } else {
            // PQ/HDR10 源：主动色调映射到 SDR
            await _safeSetProperty(player, 'target-prim', 'bt.709', 'target-prim');
            await _safeSetProperty(player, 'target-trc', 'bt.1886', 'target-trc');
            await _safeSetProperty(player, 'tone-mapping', 'bt.2390', 'tone-mapping');
            await _safeSetProperty(player, 'tone-mapping-param', 'default', 'tone-mapping-param');
            await _safeSetProperty(player, 'hdr-compute-peak', 'yes', 'hdr-compute-peak');
            await _safeSetProperty(player, 'target-peak', '100', 'target-peak');
            ServiceLocator.log.i(
                'MultiScreenProvider: HDR 源(PQ/HDR10): 色调映射到 SDR (gamma=$srcGamma, primaries=$srcPrimaries, sig-peak=$sigPeak)');
          }
        } else {
          // SDR 源（包括 4K SDR、1080p 等）：清零所有 HDR 残留参数
          await _safeSetProperty(player, 'target-prim', 'auto', 'target-prim');
          await _safeSetProperty(player, 'target-trc', 'auto', 'target-trc');
          await _safeSetProperty(player, 'hdr-compute-peak', 'no', 'hdr-compute-peak');
          ServiceLocator.log.i(
              'MultiScreenProvider: SDR 源: 标准输出 (gamma=$srcGamma, primaries=$srcPrimaries)');
        }

        // ════════════════════════════════════════════
        // 第二步：去交错增量配置 — 根据源类型选择性调整 hwdec
        // ════════════════════════════════════════════
        if (is1080i && _decodingMode != 'software') {
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
            await _safeSetProperty(player, 'deinterlace', 'no', 'deinterlace');
            await _safeSetProperty(player, 'vf', '', 'clear_vf');
            if (_d3d11vppMode == 'off') {
              // 用户关闭 d3d11vpp → 回退硬件 VPP
              await _safeSetProperty(player, 'deinterlace', 'yes', 'deinterlace');
              ServiceLocator.log.i(
                  'MultiScreenProvider: 1080i: auto-safe 流 d3d11vpp 关闭，使用 deinterlace=yes');
            } else {
              final vfStr = 'd3d11vpp=mode=$_d3d11vppMode:deint=yes:interlaced-only=yes';
              await _safeSetProperty(player, 'vf', vfStr, 'vf_d3d11vpp');
              final ok = await _verifyFilterChainActive(player, 'vf=$vfStr');
              if (ok) {
                ServiceLocator.log.i(
                    'MultiScreenProvider: 1080i: auto-safe 流使用 d3d11vpp ($_d3d11vppMode) 硬件去交错');
              } else {
                await _safeSetProperty(player, 'vf', '', 'clear_vf');
                await _safeSetProperty(player, 'deinterlace', 'yes', 'deinterlace');
                ServiceLocator.log.i(
                    'MultiScreenProvider: 1080i: auto-safe 流 d3d11vpp 不可用，退回 deinterlace=yes');
              }
            }
          } else if (isDirectFlow) {
            // —— 非 safe direct 流：deinterlace=yes 硬件去交错，零重建 ——
            await _safeSetProperty(player, 'vf', '', 'clear_vf');
            await _safeSetProperty(player, 'deinterlace', 'yes', 'deinterlace');
            ServiceLocator.log.i(
                'MultiScreenProvider: 1080i: direct 流($_windowsHwdecMode) 使用硬件去交错 (deinterlace=yes)');
          } else if (isCopyFlow) {
            // —— copy 流：软件 bwdif 优先，硬件兜底 ——
            await _safeSetProperty(player, 'deinterlace', 'no', 'deinterlace');
            await _safeSetProperty(player, 'vf', '', 'clear_vf');

            // 读取当前实际 hwdec 配置，判断是否需强制切到 copy-back 模式。
            // 反转判断：仅当明确读到 direct 模式（d3d11va/dxva2）才强制切 d3d11va-copy；
            // 读到 null/未知/auto/copy 一律不切换，避免在 videoParams 回调属性未就绪时
            // 误判为"非 copy"而反复触发解码器重建（造成约 1s 缓冲波动）。
            final currentHwdec = await _safeGetProperty(player, 'hwdec', 'hwdec');
            final needCopyForSoftwareFilter = currentHwdec == 'd3d11va' || currentHwdec == 'dxva2';
            if (needCopyForSoftwareFilter) {
              // 仅在 direct 模式时切换到 d3d11va-copy，使软件滤镜能消费帧
              await _safeSetProperty(player, 'hwdec', 'd3d11va-copy', 'hwdec_1080i');
            }

            const filters = [
              'bwdif=mode=1:parity=tff',
              'lavfi:yadif=mode=1:parity=tff',
            ];

            String? workingFilter;
            for (int retry = 0; retry < 5 && workingFilter == null; retry++) {
              if (retry > 0) await Future.delayed(const Duration(milliseconds: 50));
              for (final vf in filters) {
                await _safeSetProperty(player, 'vf', '', 'clear_vf');
                // 只有 setProperty 真正成功才做日志/error 联动验证；
                // 若 setProperty 直接抛异常（如非法滤镜 "Error parsing option"），
                // 直接跳过该滤镜尝试，不进入验证窗口。
                final setOk = await _safeSetProperty(player, 'vf', vf, 'try_vf');
                if (!setOk) continue;
                if (await _verifyFilterChainActive(player, 'vf=$vf')) {
                  workingFilter = vf;
                  ServiceLocator.log.i(
                      'MultiScreenProvider: 1080i: 软件滤镜 $vf 生效 (hwdec=$currentHwdec)');
                  break;
                }
              }
            }

            if (workingFilter == null) {
              // 软件滤镜全部不可用 → 回退到硬件去交错
              await _safeSetProperty(player, 'vf', '', 'clear_vf');
              await _safeSetProperty(player, 'hwdec', _getConfiguredHwdecMode(), 'hwdec');
              await _safeSetProperty(player, 'deinterlace', 'yes', 'deinterlace');
              ServiceLocator.log.i(
                  'MultiScreenProvider: 1080i: 软件滤镜不可用，退回硬件去交错 (deinterlace=yes)');
            }
          }
          // 其它未知配置：不干预，保持现状（用户配置指定）
        } else {
          // 分支 B: 逐行源（1080p / 2160p SDR / 2160p HDR 等）
          // 显式重置 hwdec 为用户配置模式，清除上一流可能设置的 d3d11va-copy
          // 同步阶段跳过 hwdec 设置（initialHwdecSet 已为 true），
          // 因此由异步阶段在此处确保 hwdec 正确
          await _safeSetProperty(player, 'hwdec', _getConfiguredHwdecMode(), 'hwdec_progressive');
          await _safeSetProperty(player, 'deinterlace', 'no', 'deinterlace');
          await _safeSetProperty(player, 'vf', '', 'clear_vf');
          final label = h > 0 ? '${h}p 逐行源' : '源（默认按逐行处理）';
          final currentHwdec = _decodingMode == 'software' ? '软解(no)' : _getConfiguredHwdecMode();
          ServiceLocator.log.i('MultiScreenProvider: $label: $currentHwdec 硬解, 无去交错');
        }
      });
    }
  }

  bool _shouldTrySoftwareFallback(String error, ScreenPlayerState screen) {
    if (_decodingMode == 'software') return false;
    if (!_allowSoftwareFallback) return false;
    if (screen.softwareFallbackAttempted || screen.isSoftwareDecoding) return false;
    final lower = error.toLowerCase();
    return lower.contains('codec') ||
        lower.contains('decoder') ||
        lower.contains('hwdec') ||
        lower.contains('hardware');
  }

  Future<void> _attemptSoftwareFallback(int screenIndex) async {
    final screen = _screens[screenIndex];
    if (screen.channel == null) return;
    screen.softwareFallbackAttempted = true;
    _createPlayerForScreen(screenIndex, useSoftwareDecoding: true);
    // 回退会替换播放器，必须重新挂接流监听，否则新播放器的状态/错误无法被捕获
    _setupPlayerListeners(screenIndex, screen);
    await playChannelOnScreen(screenIndex, screen.channel!, skipHistory: true);
  }

  Future<bool> _tryNextSourceOnError(
      int screenIndex, ScreenPlayerState screen, String error) async {
    final channel = screen.channel;
    if (channel == null || !channel.hasMultipleSources) return false;

    final nextIndex = channel.currentSourceIndex + 1;
    if (nextIndex >= channel.sourceCount) {
      ServiceLocator.log.d(
          'MultiScreenProvider: Screen $screenIndex all sources failed, lastError=$error');
      return false;
    }

    final nextChannel = channel.copyWith(currentSourceIndex: nextIndex);
    ServiceLocator.log.d(
        'MultiScreenProvider: Screen $screenIndex source ${channel.currentSourceIndex + 1}/${channel.sourceCount} failed, trying ${nextIndex + 1}/${channel.sourceCount}');
    await playChannelOnScreen(screenIndex, nextChannel, skipHistory: true);
    return true;
  }

  Future<void> _disposeScreenPlayer(int screenIndex) async {
    final screen = _screens[screenIndex];
    if (screen.player != null) {
      await screen.player!.stop();
      await screen.player!.dispose();
    }
    screen.player = null;
    screen.videoController = null;
    screen.isPlaying = false;
  }
  
  // 应用音量到指定屏幕
  void _applyVolumeToScreen(int screenIndex) {
    final screen = _screens[screenIndex];
    if (screen.player != null) {
      final targetVolume = screenIndex == _activeScreenIndex ? _getEffectiveVolume() : 0.0;
      ServiceLocator.log.d('MultiScreenProvider: _applyVolumeToScreen - screen=$screenIndex, active=$_activeScreenIndex, volume=$targetVolume');
      screen.player!.setVolume(targetVolume);
    }
  }
  
  // 重新应用音量到所有屏幕（用于恢复播放后确保音量正确）
  Future<void> reapplyVolumeToAllScreens() async {
    ServiceLocator.log.d('MultiScreenProvider: reapplyVolumeToAllScreens - activeScreen=$_activeScreenIndex');
    for (int i = 0; i < 4; i++) {
      _applyVolumeToScreen(i);
    }
    // 再次延迟应用，确保播放器完全就绪
    await Future.delayed(const Duration(milliseconds: 200));
    for (int i = 0; i < 4; i++) {
      _applyVolumeToScreen(i);
    }
  }

  // 停止指定屏幕的播放
  void stopScreen(int screenIndex) {
    if (screenIndex < 0 || screenIndex >= 4) return;
    
    final screen = _screens[screenIndex];
    screen.player?.stop();
    screen.isPlaying = false;
    screen.channel = null;
    notifyListeners();
  }

  // 清空指定屏幕
  void clearScreen(int screenIndex) {
    if (screenIndex < 0 || screenIndex >= 4) return;
    
    final screen = _screens[screenIndex];
    screen.dispose();
    _screens[screenIndex] = ScreenPlayerState();
    notifyListeners();
  }

  // 清空所有屏幕
  Future<void> clearAllScreens() async {
    ServiceLocator.log.d('MultiScreenProvider: clearAllScreens - stopping all players');
    final futures = <Future>[];
    for (int i = 0; i < 4; i++) {
      final screen = _screens[i];
      // 先停止播放
      if (screen.player != null) {
        ServiceLocator.log.d('MultiScreenProvider: Stopping player for screen $i');
        // 设置音量为0确保没有声音
        screen.player!.setVolume(0);
        futures.add(screen.player!.stop());
      }
    }
    // 等待所有播放器停止
    await Future.wait(futures);
    
    // 再释放资源
    for (int i = 0; i < 4; i++) {
      await _screens[i].dispose();
      _screens[i] = ScreenPlayerState();
    }
    _activeScreenIndex = 0;
    notifyListeners();
  }

  // 暂停所有屏幕（保留频道信息，以便恢复）
  void pauseAllScreens() {
    for (int i = 0; i < 4; i++) {
      final screen = _screens[i];
      // 停止并释放播放器，但保留频道信息
      screen.player?.dispose();
      screen.player = null;
      screen.videoController = null;
      screen.isPlaying = false;
    }
    notifyListeners();
  }

  // 恢复所有屏幕播放（重新播放记住的频道）
  Future<void> resumeAllScreens() async {
    for (int i = 0; i < 4; i++) {
      final screen = _screens[i];
      if (screen.channel != null) {
        // 重新播放该频道
        await playChannelOnScreen(i, screen.channel!);
      }
    }
  }

  // 检查是否有任何屏幕在播放
  bool get hasAnyChannel {
    return _screens.any((screen) => screen.channel != null);
  }

  // 获取活动屏幕的频道
  Channel? get activeChannel {
    return _screens[_activeScreenIndex].channel;
  }

  // 在默认位置播放频道
  void playChannelAtDefaultPosition(Channel channel, int defaultPosition) {
    final screenIndex = (defaultPosition - 1).clamp(0, 3);
    ServiceLocator.log.d('MultiScreenProvider: playChannelAtDefaultPosition - channel=${channel.name}, position=$defaultPosition, screenIndex=$screenIndex');
    setActiveScreen(screenIndex);
    playChannelOnScreen(screenIndex, channel);
  }

  // 切换到下一个频道（在活动屏幕）
  void playNextOnActiveScreen(List<Channel> channels) {
    final currentChannel = _screens[_activeScreenIndex].channel;
    if (currentChannel == null || channels.isEmpty) return;
    
    // 使用 id 或 name 进行比较，而不是 url（因为同一频道可能有多个源）
    final currentIndex = channels.indexWhere((c) => c.id == currentChannel.id || c.name == currentChannel.name);
    if (currentIndex == -1) return;
    
    final nextIndex = (currentIndex + 1) % channels.length;
    playChannelOnScreen(_activeScreenIndex, channels[nextIndex]);
  }

  // 切换到上一个频道（在活动屏幕）
  void playPreviousOnActiveScreen(List<Channel> channels) {
    final currentChannel = _screens[_activeScreenIndex].channel;
    if (currentChannel == null || channels.isEmpty) return;
    
    // 使用 id 或 name 进行比较，而不是 url（因为同一频道可能有多个源）
    final currentIndex = channels.indexWhere((c) => c.id == currentChannel.id || c.name == currentChannel.name);
    if (currentIndex == -1) return;
    
    final prevIndex = (currentIndex - 1 + channels.length) % channels.length;
    playChannelOnScreen(_activeScreenIndex, channels[prevIndex]);
  }

  bool shouldShowProgressBarForActiveScreen(String progressBarMode) {
    final screen = activeScreen;
    final durationSeconds = screen.duration.inSeconds;
    if (progressBarMode == 'never') return false;
    if (progressBarMode == 'always') return durationSeconds > 0;
    return screen.channel?.isSeekable == true &&
        durationSeconds > 0 &&
        durationSeconds <= 86400;
  }

  void seekActiveScreen(Duration position) {
    final screen = activeScreen;
    if (screen.player == null) return;
    screen.player!.seek(position);
  }

  Future<void> togglePlayPauseOnActiveScreen() async {
    final screen = activeScreen;
    final player = screen.player;
    if (player == null) return;
    if (screen.isPlaying) {
      await player.pause();
      screen.isPlaying = false;
    } else {
      await player.play();
      screen.isPlaying = true;
    }
    notifyListeners();
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0).toDouble();
    _applyVolumeToActiveScreen();
    notifyListeners();
  }

  void switchToNextSourceOnActiveScreen() {
    final screen = activeScreen;
    final channel = screen.channel;
    if (channel == null || !channel.hasMultipleSources) return;
    final newIndex = (channel.currentSourceIndex + 1) % channel.sourceCount;
    final nextChannel = channel.copyWith(currentSourceIndex: newIndex);
    playChannelOnScreen(_activeScreenIndex, nextChannel, skipHistory: true);
  }

  void switchToPreviousSourceOnActiveScreen() {
    final screen = activeScreen;
    final channel = screen.channel;
    if (channel == null || !channel.hasMultipleSources) return;
    final newIndex =
        (channel.currentSourceIndex - 1 + channel.sourceCount) %
            channel.sourceCount;
    final prevChannel = channel.copyWith(currentSourceIndex: newIndex);
    playChannelOnScreen(_activeScreenIndex, prevChannel, skipHistory: true);
  }

  @override
  void dispose() {
    for (final screen in _screens) {
      screen.dispose();
    }
    super.dispose();
  }
}
