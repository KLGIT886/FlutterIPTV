import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../database/database_helper.dart';
import '../platform/platform_detector.dart';
import 'update_service.dart';
import '../managers/update_manager.dart';

/// Service Locator for dependency injection
class ServiceLocator {
  static late SharedPreferences _prefs;
  static late DatabaseHelper _database;
  static late Directory _appDir;
  static late UpdateService _updateService;
  static late UpdateManager _updateManager;

  static SharedPreferences get prefs => _prefs;
  static DatabaseHelper get database => _database;
  static Directory get appDir => _appDir;
  static UpdateService get updateService => _updateService;
  static UpdateManager get updateManager => _updateManager;

  static Future<void> initPrefs() async {
    // Initialize SharedPreferences - Fast and critical for theme
    _prefs = await SharedPreferences.getInstance();

    // Detect platform
    PlatformDetector.init();
  }

  static Future<void> initDatabase() async {
    // Initialize app directory
    _appDir = await getApplicationDocumentsDirectory();

    // Initialize database
    _database = DatabaseHelper();
    await _database.initialize();
  }

  static Future<void> init() async {
    await initPrefs();
    await initDatabase();

    // Initialize update service
    _updateService = UpdateService();
    _updateManager = UpdateManager();
  }

  static Future<void> dispose() async {
    await _database.close();
  }
}
