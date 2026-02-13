import 'dart:async';
import 'service_locator.dart';

/// 自动刷新服务
/// 定期自动刷新播放列表
class AutoRefreshService {
  static final AutoRefreshService _instance = AutoRefreshService._internal();
  factory AutoRefreshService() => _instance;
  AutoRefreshService._internal();

  Timer? _timer;
  bool _isEnabled = false;
  int _intervalHours = 24;
  DateTime? _lastRefreshTime;
  Function()? _onRefreshCallback;

  bool get isEnabled => _isEnabled;
  int get intervalHours => _intervalHours;
  DateTime? get lastRefreshTime => _lastRefreshTime;

  /// 启动自动刷新
  void start({required int intervalHours, required Function() onRefresh}) {
    stop(); // 先停止现有的定时器

    _isEnabled = true;
    _intervalHours = intervalHours;
    _onRefreshCallback = onRefresh;

    ServiceLocator.log.i('启动自动刷新服务，间隔: $intervalHours小时', tag: 'AutoRefresh');

    // 设置定期检查（每小时检查一次）
    _timer = Timer.periodic(const Duration(hours: 1), (timer) {
      _checkAndRefresh();
    });
  }

  /// 停止自动刷新
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isEnabled = false;
    _onRefreshCallback = null;
    ServiceLocator.log.i('停止自动刷新服务', tag: 'AutoRefresh');
  }

  /// 在播放列表加载完成后调用，检查是否需要刷新
  void checkOnStartup() {
    if (!_isEnabled || _onRefreshCallback == null) {
      ServiceLocator.log.d('AutoRefresh: 服务未启用或回调未设置，跳过启动检查');
      return;
    }
    
    ServiceLocator.log.d('播放列表已加载，执行启动检查', tag: 'AutoRefresh');
    _checkAndRefresh();
  }

  /// 检查并执行刷新
  void _checkAndRefresh() {
    if (!_isEnabled || _onRefreshCallback == null) {
      ServiceLocator.log.d('AutoRefresh: 服务未启用或回调未设置，跳过检查');
      return;
    }

    final now = DateTime.now();
    
    ServiceLocator.log.d('AutoRefresh: 检查刷新条件');
    ServiceLocator.log.d('AutoRefresh: 当前时间: $now');
    ServiceLocator.log.d('AutoRefresh: 上次刷新: $_lastRefreshTime');
    ServiceLocator.log.d('AutoRefresh: 刷新间隔: $_intervalHours 小时');
    
    // 如果从未刷新过，设置当前时间为上次刷新时间
    if (_lastRefreshTime == null) {
      ServiceLocator.log.d('首次运行，设置初始刷新时间', tag: 'AutoRefresh');
      _lastRefreshTime = now;
      _saveLastRefreshTime();
      return;
    }
    
    // 检查是否已经超过刷新间隔
    final hoursSinceLastRefresh = now.difference(_lastRefreshTime!).inHours;
    ServiceLocator.log.d('AutoRefresh: 距离上次刷新: $hoursSinceLastRefresh 小时');
    
    if (hoursSinceLastRefresh >= _intervalHours) {
      ServiceLocator.log.i('已超过刷新间隔($hoursSinceLastRefresh小时 >= $_intervalHours小时)，触发自动刷新', tag: 'AutoRefresh');
      _lastRefreshTime = now;
      _saveLastRefreshTime();
      _onRefreshCallback!();
    } else {
      final remainingHours = _intervalHours - hoursSinceLastRefresh;
      ServiceLocator.log.d('未到刷新时间，还需等待 $remainingHours 小时', tag: 'AutoRefresh');
    }
  }

  /// 从本地加载上次刷新时间
  Future<void> loadLastRefreshTime() async {
    try {
      final timestamp = ServiceLocator.prefs.getInt('last_auto_refresh_time');
      if (timestamp != null) {
        _lastRefreshTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        ServiceLocator.log.d('加载上次刷新时间: $_lastRefreshTime', tag: 'AutoRefresh');
      }
    } catch (e) {
      ServiceLocator.log.e('加载上次刷新时间失败', tag: 'AutoRefresh', error: e);
    }
  }

  /// 保存上次刷新时间到本地
  Future<void> _saveLastRefreshTime() async {
    try {
      if (_lastRefreshTime != null) {
        await ServiceLocator.prefs.setInt(
          'last_auto_refresh_time',
          _lastRefreshTime!.millisecondsSinceEpoch,
        );
      }
    } catch (e) {
      ServiceLocator.log.d('AutoRefresh: 保存刷新时间失败: $e');
    }
  }

  /// 手动触发刷新（重置计时器）
  void manualRefresh() {
    _lastRefreshTime = DateTime.now();
    _saveLastRefreshTime();
    ServiceLocator.log.d('AutoRefresh: 手动刷新，重置计时器');
  }

  /// 获取距离下次刷新的剩余时间（小时）
  int? getHoursUntilNextRefresh() {
    if (_lastRefreshTime == null || !_isEnabled) return null;
    
    final now = DateTime.now();
    final elapsed = now.difference(_lastRefreshTime!).inHours;
    final remaining = _intervalHours - elapsed;
    
    return remaining > 0 ? remaining : 0;
  }
}
