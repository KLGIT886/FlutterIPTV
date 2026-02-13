import 'dart:io';
import 'package:flutter/services.dart';
import '../platform/platform_detector.dart';
import '../services/service_locator.dart';

class AppUpdate {
  final String version;
  final int build;
  final String releaseNotes;
  final String downloadUrl;
  final Map<String, dynamic> assets;
  final DateTime releaseDate;
  final String minVersion;

  AppUpdate({
    required this.version,
    required this.build,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.assets,
    required this.releaseDate,
    this.minVersion = '1.0.0',
  });

  // 缓存 CPU 架构
  static String? _cachedCpuAbi;
  static const _platformChannel = MethodChannel('com.flutteriptv/platform');

  /// 从 GitHub Pages version.json 解析
  static Future<AppUpdate> fromVersionJsonAsync(Map<String, dynamic> json) async {
    final assets = json['assets'] as Map<String, dynamic>? ?? {};
    final changelog = json['changelog'] as Map<String, dynamic>? ?? {};
    
    // 根据当前语言选择更新日志，默认中文
    final locale = Platform.localeName.startsWith('zh') ? 'zh' : 'en';
    final releaseNotes = changelog[locale] ?? changelog['zh'] ?? changelog['en'] ?? '';
    
    // 根据平台和架构选择下载链接
    final downloadUrl = await _getDownloadUrl(assets);

    return AppUpdate(
      version: json['version'] ?? '0.0.0',
      build: json['build'] ?? 0,
      releaseNotes: releaseNotes,
      downloadUrl: downloadUrl,
      assets: assets,
      releaseDate: DateTime.tryParse(json['releaseDate'] ?? '') ?? DateTime.now(),
      minVersion: json['minVersion'] ?? '1.0.0',
    );
  }

  /// 从 GitHub Pages version.json 解析（同步版本，使用缓存的架构）
  factory AppUpdate.fromVersionJson(Map<String, dynamic> json) {
    final assets = json['assets'] as Map<String, dynamic>? ?? {};
    final changelog = json['changelog'] as Map<String, dynamic>? ?? {};
    
    // 根据当前语言选择更新日志，默认中文
    final locale = Platform.localeName.startsWith('zh') ? 'zh' : 'en';
    final releaseNotes = changelog[locale] ?? changelog['zh'] ?? changelog['en'] ?? '';
    
    // 根据平台和架构选择下载链接（同步版本）
    final downloadUrl = _getDownloadUrlSync(assets);

    return AppUpdate(
      version: json['version'] ?? '0.0.0',
      build: json['build'] ?? 0,
      releaseNotes: releaseNotes,
      downloadUrl: downloadUrl,
      assets: assets,
      releaseDate: DateTime.tryParse(json['releaseDate'] ?? '') ?? DateTime.now(),
      minVersion: json['minVersion'] ?? '1.0.0',
    );
  }

  /// 获取 Android CPU 架构（异步）
  static Future<String> _getAndroidArch() async {
    if (_cachedCpuAbi != null) return _cachedCpuAbi!;
    
    try {
      final abi = await _platformChannel.invokeMethod<String>('getCpuAbi');
      _cachedCpuAbi = abi ?? 'armeabi-v7a';
      ServiceLocator.log.d('UPDATE: 获取到 CPU 架构: $_cachedCpuAbi');
    } catch (e) {
      ServiceLocator.log.d('UPDATE: 获取 CPU 架构失败: $e，使用默认值');
      _cachedCpuAbi = 'armeabi-v7a';
    }
    return _cachedCpuAbi!;
  }

  /// 根据平台和架构获取下载链接（异步）
  static Future<String> _getDownloadUrl(Map<String, dynamic> assets) async {
    if (Platform.isWindows) {
      return assets['windows'] ?? '';
    }
    
    if (Platform.isAndroid) {
      final arch = await _getAndroidArch();
      ServiceLocator.log.d('UPDATE: Android 架构: $arch, isTV: ${PlatformDetector.isTV}');
      
      // 根据是否是 TV 选择对应的包
      final androidAssets = PlatformDetector.isTV 
          ? assets['android_tv'] as Map<String, dynamic>?
          : assets['android_mobile'] as Map<String, dynamic>?;
      
      if (androidAssets != null) {
        // 优先使用对应架构的包，否则使用 universal
        return androidAssets[arch] ?? androidAssets['universal'] ?? '';
      }
      
      // 兼容旧格式
      return assets['android'] ?? '';
    }
    
    return '';
  }

  /// 根据平台和架构获取下载链接（同步，使用缓存）
  static String _getDownloadUrlSync(Map<String, dynamic> assets) {
    if (Platform.isWindows) {
      return assets['windows'] ?? '';
    }
    
    if (Platform.isAndroid) {
      // 使用缓存的架构，如果没有则默认 armeabi-v7a（更安全的默认值）
      final arch = _cachedCpuAbi ?? 'armeabi-v7a';
      ServiceLocator.log.d('UPDATE: Android 架构(sync): $arch, isTV: ${PlatformDetector.isTV}');
      
      // 根据是否是 TV 选择对应的包
      final androidAssets = PlatformDetector.isTV 
          ? assets['android_tv'] as Map<String, dynamic>?
          : assets['android_mobile'] as Map<String, dynamic>?;
      
      if (androidAssets != null) {
        // 优先使用对应架构的包，否则使用 universal
        return androidAssets[arch] ?? androidAssets['universal'] ?? '';
      }
      
      // 兼容旧格式
      return assets['android'] ?? '';
    }
    
    return '';
  }

  /// 预加载 CPU 架构（应用启动时调用）
  static Future<void> preloadCpuArch() async {
    if (Platform.isAndroid) {
      await _getAndroidArch();
    }
  }

  /// 从 GitHub API 解析（保留兼容性）
  factory AppUpdate.fromJson(Map<String, dynamic> json) {
    // 从tagName中提取版本号，移除'v'前缀
    String version = json['tag_name'] ?? '0.0.0';
    if (version.startsWith('v')) {
      version = version.substring(1);
    }

    // 获取发布说明
    String releaseNotes = json['body'] ?? '';

    // 获取发布时间
    DateTime releaseDate = DateTime.tryParse(json['published_at'] ?? '') ?? DateTime.now();

    // 获取下载URL
    String downloadUrl = '';
    
    if (json['assets'] != null && json['assets'] is List) {
      for (final asset in json['assets']) {
        final name = asset['name']?.toString().toLowerCase() ?? '';
        final url = asset['browser_download_url'] ?? '';
        
        if (Platform.isAndroid && name.endsWith('.apk')) {
          // 优先选择对应架构的包
          if (PlatformDetector.isTV && name.contains('tv')) {
            if (name.contains('arm64')) {
              downloadUrl = url;
              break;
            } else if (downloadUrl.isEmpty) {
              downloadUrl = url;
            }
          } else if (!PlatformDetector.isTV && name.contains('mobile')) {
            if (name.contains('arm64')) {
              downloadUrl = url;
              break;
            } else if (downloadUrl.isEmpty) {
              downloadUrl = url;
            }
          }
        } else if (Platform.isWindows && (name.endsWith('.exe') || name.endsWith('.zip'))) {
          downloadUrl = url;
        }
      }
      
      // 如果没有匹配到，使用第一个 APK/EXE
      if (downloadUrl.isEmpty && json['assets'].isNotEmpty) {
        for (final asset in json['assets']) {
          final name = asset['name']?.toString().toLowerCase() ?? '';
          final url = asset['browser_download_url'] ?? '';
          if ((Platform.isAndroid && name.endsWith('.apk')) ||
              (Platform.isWindows && (name.endsWith('.exe') || name.endsWith('.zip')))) {
            downloadUrl = url;
            break;
          }
        }
      }
    }

    return AppUpdate(
      version: version,
      build: 0,
      releaseNotes: releaseNotes,
      downloadUrl: downloadUrl,
      assets: {},
      releaseDate: releaseDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'build': build,
      'releaseNotes': releaseNotes,
      'downloadUrl': downloadUrl,
      'assets': assets,
      'releaseDate': releaseDate.toIso8601String(),
      'minVersion': minVersion,
    };
  }

  @override
  String toString() {
    return 'AppUpdate(version: $version, build: $build, downloadUrl: $downloadUrl, releaseDate: $releaseDate)';
  }
}
