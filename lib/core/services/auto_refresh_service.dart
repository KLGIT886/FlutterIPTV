import 'dart:async';
import 'package:flutter/foundation.dart';
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

    debugPrint('AutoRefresh: 启动自动刷新服务，间隔: $intervalHours小时');

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
    debugPrint('AutoRefresh: 停止自动刷新服务');
  }

  /// 在播放列表加载完成后调用，检查是否需要刷新
  void checkOnStartup() {
    if (!_isEnabled || _onRefreshCallback == null) {
      debugPrint('AutoRefresh: 服务未启用或回调未设置，跳过启动检查');
      return;
    }
    
    debugPrint('AutoRefresh: 播放列表已加载，执行启动检查');
    _checkAndRefresh();
  }

  /// 检查并执行刷新
  void _checkAndRefresh() {
    if (!_isEnabled || _onRefreshCallback == null) {
      debugPrint('AutoRefresh: 服务未启用或回调未设置，跳过检查');
      return;
    }

    final now = DateTime.now();
    
    debugPrint('AutoRefresh: 检查刷新条件');
    debugPrint('AutoRefresh: 当前时间: $now');
    debugPrint('AutoRefresh: 上次刷新: $_lastRefreshTime');
    debugPrint('AutoRefresh: 刷新间隔: $_intervalHours 小时');
    
    // 如果从未刷新过，设置当前时间为上次刷新时间
    if (_lastRefreshTime == null) {
      debugPrint('AutoRefresh: 首次运行，设置初始刷新时间');
      _lastRefreshTime = now;
      _saveLastRefreshTime();
      return;
    }
    
    // 检查是否已经超过刷新间隔
    final hoursSinceLastRefresh = now.difference(_lastRefreshTime!).inHours;
    debugPrint('AutoRefresh: 距离上次刷新: $hoursSinceLastRefresh 小时');
    
    if (hoursSinceLastRefresh >= _intervalHours) {
      debugPrint('AutoRefresh: 已超过刷新间隔，触发刷新');
      _lastRefreshTime = now;
      _saveLastRefreshTime();
      _onRefreshCallback!();
    } else {
      final remainingHours = _intervalHours - hoursSinceLastRefresh;
      debugPrint('AutoRefresh: 未到刷新时间，还需等待 $remainingHours 小时');
    }
  }

  /// 从本地加载上次刷新时间
  Future<void> loadLastRefreshTime() async {
    try {
      final timestamp = ServiceLocator.prefs.getInt('last_auto_refresh_time');
      if (timestamp != null) {
        _lastRefreshTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        debugPrint('AutoRefresh: 加载上次刷新时间: $_lastRefreshTime');
      }
    } catch (e) {
      debugPrint('AutoRefresh: 加载上次刷新时间失败: $e');
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
      debugPrint('AutoRefresh: 保存刷新时间失败: $e');
    }
  }

  /// 手动触发刷新（重置计时器）
  void manualRefresh() {
    _lastRefreshTime = DateTime.now();
    _saveLastRefreshTime();
    debugPrint('AutoRefresh: 手动刷新，重置计时器');
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
