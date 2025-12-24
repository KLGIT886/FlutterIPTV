import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart';
import '../models/app_update.dart';

class UpdateService {
  static const String _githubRepoUrl = 'https://api.github.com/repos/shnulaa/FlutterIPTV/releases';
  static const String _githubReleasesUrl = 'https://github.com/shnulaa/FlutterIPTV/releases';

  // 检查更新的间隔时间（小时）
  static const int _checkUpdateInterval = 24;

  // SharedPreferences key for last update check
  // 注释掉未使用的常量
  // static const String _lastUpdateCheckKey = 'last_update_check';

  /// 检查是否有可用更新
  Future<AppUpdate?> checkForUpdates({bool forceCheck = false}) async {
    try {
      debugPrint('UPDATE: 开始检查更新...');

      // 检查是否需要检查更新（除非强制检查）
      if (!forceCheck) {
        final lastCheck = await _getLastUpdateCheckTime();
        final now = DateTime.now();
        if (lastCheck != null && now.difference(lastCheck).inHours < _checkUpdateInterval) {
          debugPrint('UPDATE: 距离上次检查不足24小时，跳过本次检查');
          return null;
        }
      }

      // 获取当前应用版本
      final currentVersion = await getCurrentVersion();
      debugPrint('UPDATE: 当前应用版本: $currentVersion');

      // 获取最新发布信息
      final latestRelease = await _fetchLatestRelease();
      if (latestRelease == null) {
        debugPrint('UPDATE: 无法获取最新发布信息');
        return null;
      }

      debugPrint('UPDATE: 最新发布版本: ${latestRelease.version}');

      // 比较版本号
      if (_isNewerVersion(latestRelease.version, currentVersion)) {
        debugPrint('UPDATE: 发现新版本可用！');
        await _saveLastUpdateCheckTime();
        return latestRelease;
      } else {
        debugPrint('UPDATE: 已是最新版本');
        await _saveLastUpdateCheckTime();
        return null;
      }
    } catch (e) {
      debugPrint('UPDATE: 检查更新时发生错误: $e');
      return null;
    }
  }

  /// 获取当前应用版本
  Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      debugPrint('UPDATE: 获取当前版本失败: $e');
      return '0.0.0';
    }
  }

  /// 获取最新发布信息
  Future<AppUpdate?> _fetchLatestRelease() async {
    try {
      final response = await http.get(
        Uri.parse(_githubRepoUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'FlutterIPTV-App',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> releases = json.decode(response.body);
        if (releases.isNotEmpty) {
          // 返回最新的非预发布版本
          for (final release in releases) {
            if (release['prerelease'] != true) {
              return AppUpdate.fromJson(release);
            }
          }
          // 如果没有找到正式版本，返回第一个
          return AppUpdate.fromJson(releases.first);
        }
      } else {
        debugPrint('UPDATE: GitHub API请求失败，状态码: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('UPDATE: 获取发布信息时发生错误: $e');
    }
    return null;
  }

  /// 比较版本号，判断是否为新版本
  bool _isNewerVersion(String newVersion, String currentVersion) {
    try {
      final newVer = Version.parse(newVersion);
      final currentVer = Version.parse(currentVersion);
      return newVer > currentVer;
    } catch (e) {
      debugPrint('UPDATE: 版本号比较失败: $e');
      return false;
    }
  }

  /// 打开下载页面
  Future<bool> openDownloadPage() async {
    try {
      final uri = Uri.parse(_githubReleasesUrl);
      debugPrint('UPDATE: 打开下载页面: $_githubReleasesUrl');
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('UPDATE: 打开下载页面失败: $e');
      return false;
    }
  }

  /// 获取上次检查更新的时间
  Future<DateTime?> _getLastUpdateCheckTime() async {
    try {
      // 这里应该使用SharedPreferences，但为了简化，我们先返回null
      // 在实际项目中，需要导入并使用SharedPreferences
      return null;
    } catch (e) {
      debugPrint('UPDATE: 获取上次检查时间失败: $e');
      return null;
    }
  }

  /// 保存上次检查更新的时间
  Future<void> _saveLastUpdateCheckTime() async {
    try {
      // 这里应该使用SharedPreferences保存时间
      // 在实际项目中，需要导入并使用SharedPreferences
      debugPrint('UPDATE: 保存检查时间: ${DateTime.now()}');
    } catch (e) {
      debugPrint('UPDATE: 保存检查时间失败: $e');
    }
  }

  /// 检查是否是移动平台（可以显示更新对话框）
  // 注释掉未使用的方法
  // bool get _isMobilePlatform {
  //   // 这里可以添加平台检测逻辑
  //   // 移动平台显示更新对话框，桌面平台可能直接打开下载页面
  //   return true; // 暂时返回true
  // }
}
