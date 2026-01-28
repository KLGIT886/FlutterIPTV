import '../database/database_helper.dart';
import 'service_locator.dart';

/// Service for managing channel logos
class ChannelLogoService {
  final DatabaseHelper _db;
  static const String _tableName = 'channel_logos';
  
  // Cache for logo mappings
  final Map<String, String> _logoCache = {};
  bool _isInitialized = false;

  ChannelLogoService(this._db);

  /// Initialize the service and load cache
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      ServiceLocator.log.d('ChannelLogoService: 开始初始化');
      await _loadCacheFromDatabase();
      _isInitialized = true;
      ServiceLocator.log.d('ChannelLogoService: 初始化完成');
    } catch (e) {
      ServiceLocator.log.e('ChannelLogoService: 初始化失败: $e');
    }
  }

  /// Load cache from database
  Future<void> _loadCacheFromDatabase() async {
    try {
      final logos = await _db.query(_tableName);
      _logoCache.clear();
      for (final logo in logos) {
        final channelName = logo['channel_name'] as String;
        final logoUrl = logo['logo_url'] as String;
        _logoCache[_normalizeChannelName(channelName)] = logoUrl;
      }
      ServiceLocator.log.d('ChannelLogoService: 缓存加载完成，共 ${_logoCache.length} 条记录');
    } catch (e) {
      ServiceLocator.log.e('ChannelLogoService: 缓存加载失败: $e');
    }
  }

  /// Normalize channel name for matching
  String _normalizeChannelName(String name) {
    return name
        .toUpperCase()
        .replaceAll(RegExp(r'[-\s_]+'), '') // Remove spaces, dashes, underscores
        .replaceAll(RegExp(r'(综合|高清|HD|4K|8K|超清|标清|频道|卫视)'), ''); // Remove common suffixes
  }

  /// Find logo URL for a channel name with fuzzy matching
  Future<String?> findLogoUrl(String channelName) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Try exact match from cache first
    final normalized = _normalizeChannelName(channelName);
    if (_logoCache.containsKey(normalized)) {
      return _logoCache[normalized];
    }

    // Try fuzzy match from database
    try {
      final cleanName = _normalizeChannelName(channelName);
      
      // Query with LIKE for fuzzy matching
      final results = await _db.rawQuery('''
        SELECT logo_url FROM $_tableName 
        WHERE UPPER(REPLACE(REPLACE(REPLACE(channel_name, '-', ''), ' ', ''), '_', '')) LIKE ?
           OR UPPER(REPLACE(REPLACE(REPLACE(search_keys, '-', ''), ' ', ''), '_', '')) LIKE ?
        LIMIT 1
      ''', ['%$cleanName%', '%$cleanName%']);
      
      if (results.isNotEmpty) {
        final logoUrl = results.first['logo_url'] as String;
        // Cache the result
        _logoCache[normalized] = logoUrl;
        return logoUrl;
      }
    } catch (e) {
      ServiceLocator.log.w('ChannelLogoService: 查询失败: $e');
    }

    return null;
  }

  /// Get logo count from database
  Future<int> getLogoCount() async {
    try {
      final result = await _db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
      return result.first['count'] as int;
    } catch (e) {
      return 0;
    }
  }
}
