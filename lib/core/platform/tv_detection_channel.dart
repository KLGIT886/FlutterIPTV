import 'package:flutter/services.dart';
import 'platform_detector.dart';

/// Platform channel for Android TV detection
class TVDetectionChannel {
  static const MethodChannel _channel = MethodChannel('com.flutteriptv/platform');

  /// Check if the app is running on Android TV
  static Future<bool> isTV() async {
    try {
      final bool result = await _channel.invokeMethod('isTV');
      return result;
    } catch (e) {
      // If platform channel fails, fall back to heuristic detection
      return false;
    }
  }

  /// Get the device type (phone, tablet, tv)
  static Future<String> getDeviceType() async {
    try {
      final String result = await _channel.invokeMethod('getDeviceType');
      return result;
    } catch (e) {
      return 'unknown';
    }
  }

  /// Initialize TV detection and update PlatformDetector
  static Future<void> initialize() async {
    if (PlatformDetector.isAndroid) {
      final isTV = await TVDetectionChannel.isTV();
      PlatformDetector.setTVMode(isTV);
    }
  }
}
