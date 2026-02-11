import 'package:flutter/services.dart';
import 'service_locator.dart';

/// 原生日志通道服务
/// 接收来自Android原生代码的日志并写入Flutter的LogService
class NativeLogChannel {
  static const MethodChannel _channel = MethodChannel('com.flutteriptv/native_log');
  static bool _initialized = false;

  /// 初始化原生日志通道
  static Future<void> init() async {
    if (_initialized) return;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'nativeLog') {
        final level = call.arguments['level'] as String?;
        final tag = call.arguments['tag'] as String?;
        final message = call.arguments['message'] as String?;

        if (level != null && tag != null && message != null) {
          _handleNativeLog(level, tag, message);
        }
      }
    });

    _initialized = true;
  }

  /// 处理原生日志
  static void _handleNativeLog(String level, String tag, String message) {
    // 添加 [NATIVE] 前缀以区分原生日志
    final formattedMessage = '[NATIVE] [$tag] $message';

    switch (level.toLowerCase()) {
      case 'debug':
        ServiceLocator.log.d(formattedMessage);
        break;
      case 'info':
        ServiceLocator.log.i(formattedMessage);
        break;
      case 'warning':
        ServiceLocator.log.w(formattedMessage);
        break;
      case 'error':
        ServiceLocator.log.e(formattedMessage);
        break;
      default:
        ServiceLocator.log.i(formattedMessage);
    }
  }
}
