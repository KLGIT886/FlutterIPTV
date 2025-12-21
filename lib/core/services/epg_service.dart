import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:flutter/foundation.dart';

/// EPG 节目信息
class EpgProgram {
  final String channelId;
  final String title;
  final String? description;
  final DateTime start;
  final DateTime end;
  final String? category;

  EpgProgram({
    required this.channelId,
    required this.title,
    this.description,
    required this.start,
    required this.end,
    this.category,
  });

  bool get isNow {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(end);
  }

  bool get isNext {
    final now = DateTime.now();
    return start.isAfter(now);
  }

  /// 节目进度 (0.0 - 1.0)
  double get progress {
    final now = DateTime.now();
    if (now.isBefore(start)) return 0.0;
    if (now.isAfter(end)) return 1.0;
    final total = end.difference(start).inSeconds;
    final elapsed = now.difference(start).inSeconds;
    return elapsed / total;
  }

  /// 剩余时间（分钟）
  int get remainingMinutes {
    final now = DateTime.now();
    if (now.isAfter(end)) return 0;
    return end.difference(now).inMinutes;
  }
}

/// EPG 服务 - 解析和管理 EPG 数据
class EpgService {
  static final EpgService _instance = EpgService._internal();
  factory EpgService() => _instance;
  EpgService._internal();

  // channelId -> List<EpgProgram>
  final Map<String, List<EpgProgram>> _programs = {};
  
  // 频道名称映射 (用于匹配)
  final Map<String, String> _channelNames = {};
  
  DateTime? _lastUpdate;
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  DateTime? get lastUpdate => _lastUpdate;

  /// 获取频道当前节目
  EpgProgram? getCurrentProgram(String? channelId, String? channelName) {
    final programs = _findPrograms(channelId, channelName);
    if (programs == null) return null;
    
    final now = DateTime.now();
    for (final program in programs) {
      if (now.isAfter(program.start) && now.isBefore(program.end)) {
        return program;
      }
    }
    return null;
  }

  /// 获取频道下一个节目
  EpgProgram? getNextProgram(String? channelId, String? channelName) {
    final programs = _findPrograms(channelId, channelName);
    if (programs == null) return null;
    
    final now = DateTime.now();
    for (final program in programs) {
      if (program.start.isAfter(now)) {
        return program;
      }
    }
    return null;
  }

  /// 获取频道今日节目列表
  List<EpgProgram> getTodayPrograms(String? channelId, String? channelName) {
    final programs = _findPrograms(channelId, channelName);
    if (programs == null) return [];
    
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return programs.where((p) => 
      p.start.isAfter(startOfDay) && p.start.isBefore(endOfDay)
    ).toList();
  }

  List<EpgProgram>? _findPrograms(String? channelId, String? channelName) {
    // 先用 channelId 查找
    if (channelId != null && _programs.containsKey(channelId)) {
      return _programs[channelId];
    }
    
    // 用频道名称查找
    if (channelName != null) {
      final normalizedName = _normalizeName(channelName);
      for (final entry in _channelNames.entries) {
        if (_normalizeName(entry.value) == normalizedName ||
            _normalizeName(entry.key) == normalizedName) {
          if (_programs.containsKey(entry.key)) {
            return _programs[entry.key];
          }
        }
      }
    }
    
    return null;
  }

  String _normalizeName(String name) {
    return name.toLowerCase()
        .replaceAll(RegExp(r'[^\w\u4e00-\u9fa5]'), '')
        .replaceAll('hd', '')
        .replaceAll('高清', '')
        .replaceAll('标清', '')
        .replaceAll('超清', '');
  }

  /// 从 URL 加载 EPG 数据
  Future<bool> loadFromUrl(String url) async {
    if (_isLoading) return false;
    _isLoading = true;

    try {
      debugPrint('EPG: Loading from $url');
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 30),
      );
      
      if (response.statusCode != 200) {
        debugPrint('EPG: HTTP error ${response.statusCode}');
        return false;
      }

      String content;
      
      // 检查是否是 gzip 压缩
      if (url.endsWith('.gz')) {
        final decompressed = GZipCodec().decode(response.bodyBytes);
        content = _decodeContent(decompressed);
      } else {
        content = _decodeContent(response.bodyBytes);
      }

      return await _parseXmlTv(content);
    } catch (e) {
      debugPrint('EPG: Error loading: $e');
      return false;
    } finally {
      _isLoading = false;
    }
  }

  /// 智能解码内容，支持 UTF-8 和 GBK
  String _decodeContent(List<int> bytes) {
    // 先尝试 UTF-8
    try {
      final content = utf8.decode(bytes);
      // 检查是否有乱码（常见的 UTF-8 解码 GBK 的特征）
      if (!content.contains('�') && !_hasGarbledChinese(content)) {
        return content;
      }
    } catch (_) {}
    
    // 尝试 Latin1 (ISO-8859-1) 作为 GBK 的替代
    // 因为 Dart 没有内置 GBK 支持，我们用 Latin1 读取原始字节
    try {
      final latin1Content = latin1.decode(bytes);
      // 检查 XML 声明中的编码
      if (latin1Content.contains('encoding="gb2312"') || 
          latin1Content.contains('encoding="gbk"') ||
          latin1Content.contains('encoding="GB2312"') ||
          latin1Content.contains('encoding="GBK"')) {
        // 需要 GBK 解码，但 Dart 不支持，尝试用 UTF-8 with allowMalformed
        return utf8.decode(bytes, allowMalformed: true);
      }
    } catch (_) {}
    
    // 最后用 UTF-8 with allowMalformed
    return utf8.decode(bytes, allowMalformed: true);
  }

  bool _hasGarbledChinese(String content) {
    // 检查是否有常见的乱码模式
    final garbledPatterns = ['å', 'ä', 'ã', 'æ', 'ç', 'è', 'é', 'ê', 'ë', 'ì', 'í', 'î', 'ï'];
    int count = 0;
    for (final pattern in garbledPatterns) {
      if (content.contains(pattern)) count++;
    }
    // 如果有多个这样的字符，可能是乱码
    return count > 3;
  }

  Future<bool> _parseXmlTv(String content) async {
    try {
      final document = XmlDocument.parse(content);
      final tv = document.findElements('tv').firstOrNull;
      if (tv == null) {
        debugPrint('EPG: No <tv> element found');
        return false;
      }

      _programs.clear();
      _channelNames.clear();

      // 解析频道
      for (final channel in tv.findElements('channel')) {
        final id = channel.getAttribute('id');
        if (id == null) continue;
        
        final displayName = channel.findElements('display-name').firstOrNull?.innerText;
        if (displayName != null) {
          _channelNames[id] = displayName;
        }
      }

      // 解析节目
      for (final programme in tv.findElements('programme')) {
        final channelId = programme.getAttribute('channel');
        final startStr = programme.getAttribute('start');
        final stopStr = programme.getAttribute('stop');
        
        if (channelId == null || startStr == null || stopStr == null) continue;

        final start = _parseDateTime(startStr);
        final end = _parseDateTime(stopStr);
        if (start == null || end == null) continue;

        final title = programme.findElements('title').firstOrNull?.innerText ?? '';
        final desc = programme.findElements('desc').firstOrNull?.innerText;
        final category = programme.findElements('category').firstOrNull?.innerText;

        final program = EpgProgram(
          channelId: channelId,
          title: title,
          description: desc,
          start: start,
          end: end,
          category: category,
        );

        _programs.putIfAbsent(channelId, () => []).add(program);
      }

      // 按开始时间排序
      for (final programs in _programs.values) {
        programs.sort((a, b) => a.start.compareTo(b.start));
      }

      _lastUpdate = DateTime.now();
      debugPrint('EPG: Loaded ${_programs.length} channels, ${_programs.values.fold(0, (sum, list) => sum + list.length)} programs');
      
      return true;
    } catch (e) {
      debugPrint('EPG: Parse error: $e');
      return false;
    }
  }

  DateTime? _parseDateTime(String str) {
    // XMLTV 格式: 20231225120000 +0800
    try {
      final match = RegExp(r'(\d{14})').firstMatch(str);
      if (match == null) return null;
      
      final dateStr = match.group(1)!;
      return DateTime(
        int.parse(dateStr.substring(0, 4)),
        int.parse(dateStr.substring(4, 6)),
        int.parse(dateStr.substring(6, 8)),
        int.parse(dateStr.substring(8, 10)),
        int.parse(dateStr.substring(10, 12)),
        int.parse(dateStr.substring(12, 14)),
      );
    } catch (e) {
      return null;
    }
  }

  void clear() {
    _programs.clear();
    _channelNames.clear();
    _lastUpdate = null;
  }
}
