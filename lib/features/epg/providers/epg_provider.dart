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
    _loadEpgIfEnabled();
  }

  Future<void> _loadEpgIfEnabled() async {
    final prefs = ServiceLocator.prefs;
    final enabled = prefs.getBool('enable_epg') ?? true;
    final url = prefs.getString('epg_url');

    if (enabled && url != null && url.isNotEmpty) {
      await loadEpg(url);
    }
  }

  Future<bool> loadEpg(String url) async {
    if (_isLoading) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _epgService.loadFromUrl(url);
      if (success) {
        _lastUpdate = DateTime.now();
      } else {
        _error = 'Failed to load EPG data';
      }
      return success;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
      await loadEpg(url);
    }
  }
}
