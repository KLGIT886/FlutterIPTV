import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../database/database_helper.dart';
import '../platform/platform_detector.dart';
import 'update_service.dart';
import 'log_service.dart';
import 'channel_logo_service.dart';
import 'redirect_cache_service.dart';
import 'watch_history_service.dart';
import 'logo_cache_service.dart';
import 'snapshot_preview_service.dart';
import '../managers/update_manager.dart';
import '../../features/settings/providers/settings_provider.dart';

/// Service Locator for dependency injection
class ServiceLocator {
  static late SharedPreferences _prefs;
  static late DatabaseHelper _database;
  static late Directory _appDir;
  static late UpdateService _updateService;
  static late UpdateManager _updateManager;
  static late LogService _logService;
  static late ChannelLogoService _channelLogoService;
  static late RedirectCacheService _redirectCache;
  static late WatchHistoryService _watchHistory;
  static late LogoCacheService _logoCache;
  static late SnapshotPreviewService _snapshotPreview;
  static SettingsProvider? _settings; // Nullable because it's initialized later

  static SharedPreferences get prefs => _prefs;
  static DatabaseHelper get database => _database;
  static Directory get appDir => _appDir;
  static UpdateService get updateService => _updateService;
  static UpdateManager get updateManager => _updateManager;
  static LogService get log => _logService;
  static ChannelLogoService get channelLogo => _channelLogoService;
  static RedirectCacheService get redirectCache => _redirectCache;
  static WatchHistoryService get watchHistory => _watchHistory;
  static LogoCacheService get logoCache => _logoCache;
  static SnapshotPreviewService get snapshotPreview => _snapshotPreview;
  static SettingsProvider? get settings => _settings;
  
  /// Check if log service is initialized
  static bool get isLogInitialized {
    try {
      return true; // _logService is always initialized after initPrefs()
    } catch (e) {
      return false;
    }
  }

  static Future<void> initPrefs() async {
    // Initialize SharedPreferences - Fast and critical for theme
    _prefs = await SharedPreferences.getInstance();
    
    // Initialize log service early (after prefs) - pass prefs to avoid circular dependency
    _logService = LogService();
    await _logService.init(prefs: _prefs);

    // Detect platform (after log service is initialized)
    await PlatformDetector.init();
  }

  static Future<void> initDatabase() async {
    // Initialize app directory
    _appDir = await getApplicationDocumentsDirectory();

    // Initialize database
    _database = DatabaseHelper();
    await _database.initialize();

    // Initialize channel logo service (after database)
    _channelLogoService = ChannelLogoService(_database);
    // Initialize in background to avoid blocking app startup
    _channelLogoService.initialize().catchError((e) {
      log.e('Failed to initialize channel logo service: $e');
    });

    // Initialize watch history service (after database)
    _watchHistory = WatchHistoryService();
  }

  static Future<void> init() async {
    await initPrefs();
    await initDatabase();

    // Initialize update service
    _updateService = UpdateService();
    _updateManager = UpdateManager();
    
    // Initialize redirect cache service
    _redirectCache = RedirectCacheService();

    // Initialize logo cache service (before SettingsProvider 因为 channel_logo_widget 可能先访问)
    // 使用用户保存的配置（如果 prefs 中有），否则使用默认值
    final enabled = _prefs.getBool('logo_cache_enabled') ?? LogoCacheService.defaultEnabled;
    final days = _prefs.getInt('logo_cache_days') ?? LogoCacheService.defaultStalePeriod.inDays;
    final maxObjects = _prefs.getInt('logo_cache_max_objects') ?? LogoCacheService.defaultMaxNrOfCacheObjects;
    _logoCache = LogoCacheService(
      stalePeriod: Duration(days: days),
      maxNrOfCacheObjects: maxObjects,
      enabled: enabled,
    );
    log.i('[ServiceLocator] LogoCacheService 已初始化: enabled=$enabled, $days天, max=$maxObjects');

    // Initialize snapshot preview service
    _snapshotPreview = SnapshotPreviewService();
  }

  /// Register settings provider (called from main.dart after SettingsProvider is created)
  static void registerSettings(SettingsProvider settings) {
    _settings = settings;
  }

  static Future<void> dispose() async {
    // 刷新日志缓冲区
    try {
      await _logService.flush();
    } catch (e) {
      // 使用 debugPrint 而不是 ServiceLocator.log，因为在 dispose 中日志服务可能不可用
      debugPrint('ServiceLocator: 刷新日志失败 - $e');
    }
    
    _snapshotPreview.dispose();
    await _database.close();
  }
}
