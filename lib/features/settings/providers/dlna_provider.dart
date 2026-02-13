import 'package:flutter/foundation.dart';
import '../../../core/services/dlna_service.dart';
import '../../../core/services/service_locator.dart';

/// DLNA 服务状态管理
class DlnaProvider extends ChangeNotifier {
  final DlnaService _dlnaService = DlnaService();
  static const String _keyDlnaEnabled = 'dlna_enabled';

  bool _isEnabled = false;
  bool _isRunning = false;
  bool _isActiveSession = false; // 是否有活跃的 DLNA 投屏会话
  String? _pendingUrl;
  String? _pendingTitle;

  bool get isEnabled => _isEnabled;
  bool get isRunning => _isRunning;
  bool get isActiveSession => _isActiveSession; // 是否正在 DLNA 投屏
  String get deviceName => _dlnaService.deviceName;
  String? get pendingUrl => _pendingUrl;
  String? get pendingTitle => _pendingTitle;

  // 播放回调（由外部设置）
  Function(String url, String? title)? onPlayRequested;
  Function()? onPauseRequested;
  Function()? onStopRequested;
  Function(Duration position)? onSeekRequested;
  Function(int volume)? onVolumeRequested;

  DlnaProvider() {
    _setupCallbacks();
    // 后台异步启动 DLNA 服务
    Future.microtask(() => _autoStart());
  }
  
  /// 自动启动 DLNA 服务（如果之前启用过）
  Future<void> _autoStart() async {
    try {
      final prefs = ServiceLocator.prefs;
      // 打印所有 SharedPreferences 的 keys 用于调试
      final allKeys = prefs.getKeys();
      ServiceLocator.log.d('SharedPreferences keys = $allKeys', tag: 'DLNA');
      
      final wasEnabled = prefs.getBool(_keyDlnaEnabled) ?? false;
      ServiceLocator.log.d('检查自动启动状态 - key=$_keyDlnaEnabled, wasEnabled=$wasEnabled', tag: 'DLNA');
      
      if (wasEnabled) {
        ServiceLocator.log.d('后台自动启动服务...', tag: 'DLNA');
        final success = await setEnabled(true);
        ServiceLocator.log.d('自动启动${success ? '成功' : '失败'}', tag: 'DLNA');
      }
    } catch (e, stack) {
      ServiceLocator.log.e('DLNA: 自动启动失败 - $e');
      ServiceLocator.log.e('DLNA: Stack trace - $stack');
    }
  }

  void _setupCallbacks() {
    _dlnaService.onPlayUrl = (url, title) {
      _pendingUrl = url;
      _pendingTitle = title;
      _isActiveSession = true;
      notifyListeners();
      onPlayRequested?.call(url, title);
    };

    _dlnaService.onPause = () {
      onPauseRequested?.call();
    };

    _dlnaService.onStop = () {
      _pendingUrl = null;
      _pendingTitle = null;
      _isActiveSession = false;
      notifyListeners();
      onStopRequested?.call();
    };

    _dlnaService.onSetVolume = (volume) {
      onVolumeRequested?.call(volume);
    };

    _dlnaService.onSeek = (position) {
      onSeekRequested?.call(position);
    };
  }

  /// 启用/禁用 DLNA 服务
  Future<bool> setEnabled(bool enabled) async {
    if (enabled == _isEnabled) return true;

    if (enabled) {
      final success = await _dlnaService.start();
      if (success) {
        _isEnabled = true;
        _isRunning = true;
        // 保存启用状态
        try {
          final prefs = ServiceLocator.prefs;
          await prefs.setBool(_keyDlnaEnabled, true);
          ServiceLocator.log.d('已保存启用状态 - key=$_keyDlnaEnabled, value=true', tag: 'DLNA');
          // 验证保存是否成功
          final saved = prefs.getBool(_keyDlnaEnabled);
          ServiceLocator.log.d('验证保存结果 - saved=$saved', tag: 'DLNA');
        } catch (e) {
          ServiceLocator.log.d('保存启用状态失败 - $e', tag: 'DLNA');
        }
        notifyListeners();
        return true;
      }
      return false;
    } else {
      await _dlnaService.stop();
      _isEnabled = false;
      _isRunning = false;
      _isActiveSession = false;
      _pendingUrl = null;
      _pendingTitle = null;
      // 保存禁用状态
      try {
        final prefs = ServiceLocator.prefs;
        await prefs.setBool(_keyDlnaEnabled, false);
        ServiceLocator.log.d('已保存禁用状态 - key=$_keyDlnaEnabled, value=false', tag: 'DLNA');
      } catch (e) {
        ServiceLocator.log.d('保存禁用状态失败 - $e', tag: 'DLNA');
      }
      notifyListeners();
      return true;
    }
  }

  /// 更新播放状态（供 PlayerProvider 调用）
  void updatePlayState({
    String? state,
    Duration? position,
    Duration? duration,
  }) {
    _dlnaService.updatePlayState(
      state: state,
      position: position,
      duration: duration,
    );
  }
  
  /// 通知 DLNA 服务播放已停止（主动退出时调用）
  void notifyPlaybackStopped() {
    _dlnaService.updatePlayState(state: 'STOPPED');
    _pendingUrl = null;
    _pendingTitle = null;
    _isActiveSession = false;
    notifyListeners();
  }
  
  /// 同步播放器状态到 DLNA（定期调用）
  void syncPlayerState({
    required bool isPlaying,
    required bool isPaused,
    required Duration position,
    required Duration duration,
  }) {
    String state;
    if (isPlaying) {
      state = 'PLAYING';
    } else if (isPaused) {
      state = 'PAUSED_PLAYBACK';
    } else {
      state = 'STOPPED';
    }
    
    _dlnaService.updatePlayState(
      state: state,
      position: position,
      duration: duration,
    );
  }

  /// 清除待播放内容
  void clearPending() {
    _pendingUrl = null;
    _pendingTitle = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _dlnaService.stop();
    super.dispose();
  }
}
