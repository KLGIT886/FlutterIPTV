import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'platform_detector.dart';
import '../services/epg_service.dart';

/// Service to launch native Android player via MethodChannel
class NativePlayerChannel {
  static const _channel = MethodChannel('com.flutteriptv/native_player');
  static bool _initialized = false;
  static Function? _onPlayerClosedCallback;

  /// Initialize the channel
  static void init() {
    if (_initialized) return;
    _initialized = true;

    // Listen for player closed event from native
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPlayerClosed') {
        debugPrint('NativePlayerChannel: Player closed from native');
        _onPlayerClosedCallback?.call();
        _onPlayerClosedCallback = null;
      } else if (call.method == 'getEpgInfo') {
        // Native player requests EPG info for a channel
        final channelName = call.arguments['channelName'] as String?;
        final epgId = call.arguments['epgId'] as String?;
        return _getEpgInfo(epgId, channelName);
      }
    });
  }

  static Map<String, dynamic>? _getEpgInfo(String? epgId, String? channelName) {
    final epgService = EpgService();
    final currentProgram = epgService.getCurrentProgram(epgId, channelName);
    final nextProgram = epgService.getNextProgram(epgId, channelName);

    if (currentProgram == null && nextProgram == null) return null;

    return {
      'currentTitle': currentProgram?.title,
      'currentRemaining': currentProgram?.remainingMinutes,
      'nextTitle': nextProgram?.title,
    };
  }

  /// Check if native player is available (Android TV only)
  static Future<bool> isAvailable() async {
    if (!PlatformDetector.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod<bool>('isNativePlayerAvailable');
      return result ?? false;
    } catch (e) {
      debugPrint('NativePlayerChannel: isAvailable error: $e');
      return false;
    }
  }

  /// Launch native player with given URL, channel name, and optional channel list for switching
  /// Returns true if launched successfully
  static Future<bool> launchPlayer({
    required String url,
    String name = '',
    int index = 0,
    List<String>? urls,
    List<String>? names,
    List<String>? groups,
    Function? onClosed,
  }) async {
    try {
      init(); // Ensure initialized
      _onPlayerClosedCallback = onClosed;

      debugPrint('NativePlayerChannel: launching player with url=$url, name=$name, index=$index, channels=${urls?.length ?? 0}');
      final result = await _channel.invokeMethod<bool>('launchPlayer', {
        'url': url,
        'name': name,
        'index': index,
        'urls': urls,
        'names': names,
        'groups': groups,
      });
      debugPrint('NativePlayerChannel: launch result=$result');
      return result ?? false;
    } catch (e) {
      debugPrint('NativePlayerChannel: launchPlayer error: $e');
      _onPlayerClosedCallback = null;
      return false;
    }
  }

  /// Close the native player
  static Future<void> closePlayer() async {
    try {
      await _channel.invokeMethod('closePlayer');
    } catch (e) {
      debugPrint('NativePlayerChannel: closePlayer error: $e');
    }
  }
}
