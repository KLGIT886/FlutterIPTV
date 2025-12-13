import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../database/database_helper.dart';
import '../platform/platform_detector.dart';

/// Service Locator for dependency injection
class ServiceLocator {
  static late SharedPreferences _prefs;
  static late DatabaseHelper _database;
  static late Directory _appDir;
  
  static SharedPreferences get prefs => _prefs;
  static DatabaseHelper get database => _database;
  static Directory get appDir => _appDir;
  
  static Future<void> init() async {
    // Initialize SharedPreferences
    _prefs = await SharedPreferences.getInstance();
    
    // Initialize app directory
    _appDir = await getApplicationDocumentsDirectory();
    
    // Initialize database
    _database = DatabaseHelper();
    await _database.initialize();
    
    // Detect platform
    PlatformDetector.init();
  }
  
  static Future<void> dispose() async {
    await _database.close();
  }
}
