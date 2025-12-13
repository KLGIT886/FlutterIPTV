import 'dart:io';
import 'package:flutter/foundation.dart';

/// Detects the current platform and provides platform-specific helpers
class PlatformDetector {
  static late PlatformType _currentPlatform;
  static bool _isTV = false;
  
  static PlatformType get currentPlatform => _currentPlatform;
  static bool get isTV => _isTV;
  static bool get isMobile => _currentPlatform == PlatformType.android && !_isTV;
  static bool get isDesktop => _currentPlatform == PlatformType.windows || 
                               _currentPlatform == PlatformType.macos || 
                               _currentPlatform == PlatformType.linux;
  static bool get isAndroid => _currentPlatform == PlatformType.android;
  static bool get isWindows => _currentPlatform == PlatformType.windows;
  
  /// Whether D-Pad navigation should be enabled
  static bool get useDPadNavigation => _isTV || isDesktop;
  
  /// Whether touch input is the primary input method
  static bool get useTouchInput => isMobile;
  
  static void init() {
    if (kIsWeb) {
      _currentPlatform = PlatformType.web;
    } else if (Platform.isAndroid) {
      _currentPlatform = PlatformType.android;
      _detectAndroidTV();
    } else if (Platform.isWindows) {
      _currentPlatform = PlatformType.windows;
    } else if (Platform.isIOS) {
      _currentPlatform = PlatformType.ios;
    } else if (Platform.isMacOS) {
      _currentPlatform = PlatformType.macos;
    } else if (Platform.isLinux) {
      _currentPlatform = PlatformType.linux;
    } else {
      _currentPlatform = PlatformType.unknown;
    }
  }
  
  static void _detectAndroidTV() {
    // Android TV detection will be done via platform channel
    // For now, we'll check environment or use a flag
    // This can be enhanced with actual Android TV detection
    _isTV = const bool.fromEnvironment('IS_TV', defaultValue: false);
  }
  
  /// Force TV mode (useful for testing)
  static void setTVMode(bool isTV) {
    _isTV = isTV;
  }
  
  /// Get appropriate grid count based on platform
  static int getGridCrossAxisCount(double screenWidth) {
    if (_isTV || isDesktop) {
      if (screenWidth > 1600) return 6;
      if (screenWidth > 1200) return 5;
      if (screenWidth > 900) return 4;
      return 3;
    } else {
      if (screenWidth > 600) return 3;
      return 2;
    }
  }
  
  /// Get appropriate thumbnail size based on platform
  static double getThumbnailHeight() {
    if (_isTV) return 180;
    if (isDesktop) return 160;
    return 120;
  }
  
  /// Get focus border width for TV/Desktop
  static double getFocusBorderWidth() {
    if (_isTV) return 4;
    if (isDesktop) return 3;
    return 2;
  }
}

enum PlatformType {
  android,
  ios,
  windows,
  macos,
  linux,
  web,
  unknown,
}
