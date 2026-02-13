import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/services/epg_service.dart';
import '../../../core/services/service_locator.dart';

class EpgProvider extends ChangeNotifier {
  final EpgService _epgService = EpgService();

  bool _isLoading = false;
  String? _error;
  DateTime? _lastUpdate;

  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastUpdate => _lastUpdate ?? _epgService.lastUpdate;
  bool get hasData => _epgService.lastUpdate != null;

  EpgProvider() {
    // Load EPG in background without blocking
    _loadEpgIfEnabled();
  }

  Future<void> _loadEpgIfEnabled() async {
    final prefs = ServiceLocator.prefs;
    final enabled = prefs.getBool('enable_epg') ?? true;
    final url = prefs.getString('epg_url');

    if (enabled && url != null && url.isNotEmpty) {
      // Load in background, don't await
      loadEpg(url).then((_) {
        ServiceLocator.log.d('EPG: Background loading completed');
      }).catchError((e) {
        ServiceLocator.log.w('EPG: Background loading failed: $e');
      });
    }
  }

  Future<bool> loadEpg(String url, {String? fallbackUrl, bool silent = true}) async {
    // Don't block if already loading
    if (_isLoading) {
      ServiceLocator.log.d('EPG: Already loading, skipping');
      return false;
    }

    _isLoading = true;
    _error = null;
    
    // Only notify if not silent (user-initiated refresh)
    if (!silent) {
      notifyListeners();
    }

    bool success = false;
    
    try {
      // Try primary URL first
      ServiceLocator.log.d('EPG: Attempting to load from primary URL: $url');
      success = await _epgService.loadFromUrl(url);
      
      if (success) {
        _lastUpdate = DateTime.now();
        ServiceLocator.log.d('EPG: Successfully loaded from primary URL');
      } else if (fallbackUrl != null && fallbackUrl.isNotEmpty && fallbackUrl != url) {
        // If primary failed and fallback is available, try fallback
        ServiceLocator.log.d('EPG: Primary URL failed, trying fallback URL: $fallbackUrl');
        success = await _epgService.loadFromUrl(fallbackUrl);
        
        if (success) {
          _lastUpdate = DateTime.now();
          ServiceLocator.log.d('EPG: Successfully loaded from fallback URL');
        }
      }
      
      if (!success) {
        _error = 'Failed to load EPG data from all sources';
      }
    } catch (e) {
      _error = e.toString();
      ServiceLocator.log.w('EPG: Error loading', error: e);
      success = false;
    } finally {
      _isLoading = false;
      // Only notify if not silent (user-initiated refresh)
      if (!silent) {
        notifyListeners();
      }
    }
    
    return success;
  }

  /// 获取频道当前节目
  EpgProgram? getCurrentProgram(String? channelId, String? channelName) {
    return _epgService.getCurrentProgram(channelId, channelName);
  }

  /// 获取频道下一个节目
  EpgProgram? getNextProgram(String? channelId, String? channelName) {
    return _epgService.getNextProgram(channelId, channelName);
  }

  /// 获取频道今日节目列表
  List<EpgProgram> getTodayPrograms(String? channelId, String? channelName) {
    return _epgService.getTodayPrograms(channelId, channelName);
  }

  /// 获取频道指定时区的节目列表（时间范围：前5天到后2天）
  List<EpgProgram> getProgramsInTimeRange(String? channelId, String? channelName, int hourOffset, {int daysBefore = 5, int daysAfter = 2}) {
    return _epgService.getProgramsInTimeRange(channelId, channelName, hourOffset, daysBefore: daysBefore, daysAfter: daysAfter);
  }

  void clear() {
    _epgService.clear();
    _lastUpdate = null;
    _error = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    final prefs = ServiceLocator.prefs;
    final url = prefs.getString('epg_url');
    if (url != null && url.isNotEmpty) {
      // User-initiated refresh, show loading state
      await loadEpg(url, silent: false);
    }
  }
}
