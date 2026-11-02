import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import '../services/service_locator.dart';

/// Windows 迷你播放器模式控制
class WindowsPipChannel {
  static bool _isInMiniMode = false;
  static bool _isPinned = false;
  static Size? _originalSize;
  static Offset? _originalPosition;
  static bool _wasMaximized = false;
  static bool _wasFullScreen = false;
  
  // 迷你模式的默认尺寸
  static const double _miniWidth = 400;
  static const double _miniHeight = 225; // 16:9 比例
  static const double _margin = 20;

  // 状态变化通知器
  static final ValueNotifier<bool> pipModeNotifier = ValueNotifier<bool>(false);

  /// 是否在迷你模式
  static bool get isInPipMode => _isInMiniMode;

  /// 是否置顶
  static bool get isPinned => _isPinned;

  /// 是否支持（仅 Windows 桌面）
  static bool get isSupported => !kIsWeb && Platform.isWindows;

  /// 当前应用窗口
  static Window? get _window => WindowManager.instance.getCurrent();

  /// 进入迷你模式
  static Future<bool> enterPipMode() async {
    if (!isSupported || _isInMiniMode) return false;

    final window = _window;
    if (window == null) return false;

    try {
      // 保存原始窗口状态
      _wasFullScreen = window.isFullScreen;
      _wasMaximized = window.isMaximized;

      // 如果是全屏，先退出全屏
      if (_wasFullScreen) {
        window.isFullScreen = false;
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // 如果是最大化，先取消最大化
      if (_wasMaximized) {
        window.unmaximize();
        await Future.delayed(const Duration(milliseconds: 200));
      }

      _originalSize = window.size.toSize();
      _originalPosition = window.position.toOffset();

      // 获取主屏幕尺寸
      final primaryDisplay = DisplayManager.instance.getPrimary();
      if (primaryDisplay == null) return false;
      final screenSize = primaryDisplay.size.toSize();

      ServiceLocator.log.d(
          'WindowsPipChannel: 屏幕尺寸 - ${screenSize.width} x ${screenSize.height}');

      // 计算右下角位置，紧贴屏幕底部（覆盖任务栏）
      final x = screenSize.width - _miniWidth - _margin;
      final y = screenSize.height - _miniHeight - _margin;

      ServiceLocator.log.d('WindowsPipChannel: 目标位置 - ($x, $y)');

      // 隐藏标题栏
      window.titleBarStyle = TitleBarStyle.hidden;

      // 设置窗口属性
      window.minimumSize = const Size(320, 180).toNative();
      window.setSize(const Size(_miniWidth, _miniHeight).toNative(), false);
      await Future.delayed(const Duration(milliseconds: 100));

      // 移动到右下角
      window.position = Offset(x, y).toNative();
      await Future.delayed(const Duration(milliseconds: 100));

      // 置顶 + 跳过任务栏（这样 Win+D 不会最小化，且任务栏不显示图标）
      window.isAlwaysOnTop = true;
      window.isVisibleInTaskbar = false;
      
      _isInMiniMode = true;
      _isPinned = true;
      pipModeNotifier.value = true; // 通知状态变化
      
      ServiceLocator.log.d('WindowsPipChannel: 进入迷你模式成功');
      return true;
    } catch (e) {
      ServiceLocator.log.d('WindowsPipChannel: enterPipMode error: $e');
      return false;
    }
  }

  /// 退出迷你模式
  static Future<bool> exitPipMode() async {
    if (!isSupported || !_isInMiniMode) return false;

    final window = _window;
    if (window == null) return false;

    try {
      // 取消置顶和跳过任务栏
      window.isAlwaysOnTop = false;
      window.isVisibleInTaskbar = true;

      // 恢复标题栏
      window.titleBarStyle = TitleBarStyle.hidden;

      // 恢复最小尺寸限制
      window.minimumSize = const Size(360, 600).toNative();

      // 恢复原始大小和位置
      if (_originalSize != null) {
        window.setSize(_originalSize!.toNative(), false);
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (_originalPosition != null) {
        window.position = _originalPosition!.toNative();
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // 恢复最大化状态
      if (_wasMaximized) {
        await Future.delayed(const Duration(milliseconds: 100));
        window.maximize();
      }

      // 恢复全屏状态 - 使用 microtask 避免阻塞
      if (_wasFullScreen) {
        Future.microtask(() async {
          await Future.delayed(const Duration(milliseconds: 200));
          try {
            window.isFullScreen = true;
            ServiceLocator.log.d('WindowsPipChannel: 全屏状态已恢复');
          } catch (e) {
            ServiceLocator.log.d('WindowsPipChannel: 恢复全屏失败: $e');
          }
        });
      }

      _isInMiniMode = false;
      _isPinned = false;
      pipModeNotifier.value = false; // 通知状态变化
      
      ServiceLocator.log.d('WindowsPipChannel: 退出迷你模式');
      return true;
    } catch (e) {
      ServiceLocator.log.d('WindowsPipChannel: exitPipMode error: $e');
      return false;
    }
  }

  /// 切换迷你模式
  static Future<bool> togglePipMode() async {
    if (_isInMiniMode) {
      return exitPipMode();
    } else {
      return enterPipMode();
    }
  }

  /// 切换置顶状态
  static Future<bool> togglePin() async {
    if (!isSupported) return false;

    final window = _window;
    if (window == null) return false;

    try {
      _isPinned = !_isPinned;
      window.isAlwaysOnTop = _isPinned;
      ServiceLocator.log.d('WindowsPipChannel: 置顶状态: $_isPinned');
      return true;
    } catch (e) {
      ServiceLocator.log.d('WindowsPipChannel: togglePin error: $e');
      return false;
    }
  }
  
  /// 重置状态（用于应用退出时）
  static void reset() {
    _isInMiniMode = false;
    _isPinned = false;
    _originalSize = null;
    _originalPosition = null;
    _wasMaximized = false;
    _wasFullScreen = false;
  }
}
