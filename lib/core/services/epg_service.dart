import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:flutter/foundation.dart';
import './service_locator.dart';

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

  // 频道名称索引 (normalizedName -> channelId) 用于快速查找
  final Map<String, String> _nameIndex = {};

  // EPG 查询缓存 (channelKey -> channelId)
  final Map<String, String?> _lookupCache = {};

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

    return programs
        .where((p) => p.start.isAfter(startOfDay) && p.start.isBefore(endOfDay))
        .toList();
  }

  List<EpgProgram>? _findPrograms(String? channelId, String? channelName) {
    // 生成缓存 key
    final cacheKey = '${channelId ?? ''}_${channelName ?? ''}';

    // 检查缓存
    if (_lookupCache.containsKey(cacheKey)) {
      final cachedId = _lookupCache[cacheKey];
      if (cachedId != null && _programs.containsKey(cachedId)) {
        return _programs[cachedId];
      }
      return null;
    }

    // 先用 channelId 查找
    if (channelId != null &&
        channelId.isNotEmpty &&
        _programs.containsKey(channelId)) {
      _lookupCache[cacheKey] = channelId;
      return _programs[channelId];
    }

    // 用频道名称索引快速查找
    if (channelName != null && channelName.isNotEmpty) {
      final normalizedName = _normalizeName(channelName);

      if (_nameIndex.containsKey(normalizedName)) {
        final foundId = _nameIndex[normalizedName]!;
        _lookupCache[cacheKey] = foundId;
        return _programs[foundId];
      }

      // 尝试用 channelId 作为名称查找
      if (channelId != null && channelId.isNotEmpty) {
        final normalizedId = _normalizeName(channelId);
        if (_nameIndex.containsKey(normalizedId)) {
          final foundId = _nameIndex[normalizedId]!;
          _lookupCache[cacheKey] = foundId;
          return _programs[foundId];
        }
      }
    }

    // 缓存未找到的结果
    _lookupCache[cacheKey] = null;
    return null;
  }

  /// 规范化频道名称，用于智能匹配
  /// 参考台标服务的匹配逻辑
  String _normalizeName(String name) {
    String normalized = name.toUpperCase();

    // 1. 先去除空格、横线、下划线（保留 + 号），统一格式
    normalized = normalized.replaceAll(RegExp(r'[-\s_]+'), '');

    // 2. 特殊处理：CCTV01 -> CCTV1
    normalized = normalized.replaceAllMapped(
      RegExp(r'CCTV0*(\d+)'),
      (match) => 'CCTV${match.group(1)}',
    );

    // 3. 去除英文后缀
    normalized = normalized.replaceAll(RegExp(r'(HD|4K|8K|FHD|UHD|SD)'), '');

    // 4. 去除中文后缀（匹配末尾的修饰词）
    normalized = normalized.replaceAll(
      RegExp(r'(高清|超清|蓝光|高码率|低码率|标清|频道)$'),
      '',
    );

    // 5. 特殊处理 CCTV 频道：去除中文描述（如 CCTV1综合 -> CCTV1）
    normalized = normalized.replaceAllMapped(
      RegExp(r'(CCTV\d+\+?)[\u4e00-\u9fa5]+'),
      (match) => match.group(1)!,
    );

    // 6. 特殊处理：保留"卫视"
    if (!normalized.endsWith('卫视') && name.toUpperCase().contains('卫视')) {
      // 如果原名包含卫视但被去掉了，加回来
      final wsMatch = RegExp(r'(.+?)卫视')
          .firstMatch(name.toUpperCase().replaceAll(RegExp(r'[-\s_]+'), ''));
      if (wsMatch != null) {
        normalized = '${wsMatch.group(1)!}卫视';
      }
    }

    // 7. 去除卫视后缀的修饰词
    normalized = normalized.replaceAll(
      RegExp(r'(卫视)(高清|超清)$'),
      r'$1',
    );

    return normalized;
  }

  /// 从 URL 加载 EPG 数据
  Future<bool> loadFromUrl(String url) async {
    if (_isLoading) return false;
    _isLoading = true;

    try {
      ServiceLocator.log.d('EPG: Loading from $url');

      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode != 200) {
        ServiceLocator.log.d('EPG: HTTP error ${response.statusCode}');
        return false;
      }

      // 在后台 isolate 中解析 XML，避免阻塞 UI
      final computeData = {
        'bytes': response.bodyBytes,
        'isGzip': url.endsWith('.gz'),
      };

      final result = await compute(_parseXmlTvInBackground, computeData);

      if (result != null) {
        // Use scheduleMicrotask to ensure we're on the main thread
        scheduleMicrotask(() {
          _programs.clear();
          _channelNames.clear();
          _nameIndex.clear();
          _lookupCache.clear();

          _programs.addAll(result['programs'] as Map<String, List<EpgProgram>>);
          _channelNames.addAll(result['channelNames'] as Map<String, String>);
          _nameIndex.addAll(result['nameIndex'] as Map<String, String>);

          _lastUpdate = DateTime.now();
          ServiceLocator.log.d(
              'EPG: Loaded ${_programs.length} channels, ${_programs.values.fold(0, (sum, list) => sum + list.length)} programs');
        });
        return true;
      }
      return false;
    } catch (e) {
      ServiceLocator.log.d('EPG: Error loading: $e');
      return false;
    } finally {
      _isLoading = false;
    }
  }

  /// 在后台 isolate 中解析 XML
  static Map<String, dynamic>? _parseXmlTvInBackground(
      Map<String, dynamic> data) {
    try {
      final bytes = data['bytes'] as List<int>;
      final isGzip = data['isGzip'] as bool;

      String content;
      if (isGzip) {
        final decompressed = GZipCodec().decode(bytes);
        content = _decodeContentStatic(decompressed);
      } else {
        content = _decodeContentStatic(bytes);
      }

      final document = XmlDocument.parse(content);
      final tv = document.findElements('tv').firstOrNull;
      if (tv == null) return null;

      final programs = <String, List<EpgProgram>>{};
      final channelNames = <String, String>{};
      final nameIndex = <String, String>{};

      // 解析频道
      for (final channel in tv.findElements('channel')) {
        final id = channel.getAttribute('id');
        if (id == null) continue;

        // 支持两种格式：
        // 1. <channel id="11"><display-name>CCTV1</display-name></channel>
        // 2. <channel id="11" display-name="CCTV1"></channel>
        var displayName =
            channel.findElements('display-name').firstOrNull?.innerText;
        displayName ??= channel.getAttribute('display-name');

        if (displayName != null) {
          channelNames[id] = displayName;
          nameIndex[_normalizeNameStatic(displayName)] = id;
          nameIndex[_normalizeNameStatic(id)] = id;
        }
      }

      // 解析节目 (支持 programme 和 program 两种标签)
      final programmes = tv.findElements('programme').toList();
      programmes.addAll(tv.findElements('program'));

      for (final programme in programmes) {
        final channelId = programme.getAttribute('channel');
        final startStr = programme.getAttribute('start');
        final stopStr = programme.getAttribute('stop');

        if (channelId == null || startStr == null || stopStr == null) continue;

        final start = _parseDateTimeStatic(startStr);
        final end = _parseDateTimeStatic(stopStr);
        if (start == null || end == null) continue;

        final title =
            programme.findElements('title').firstOrNull?.innerText ?? '';
        final desc = programme.findElements('desc').firstOrNull?.innerText;
        final category =
            programme.findElements('category').firstOrNull?.innerText;

        final program = EpgProgram(
          channelId: channelId,
          title: title,
          description: desc,
          start: start,
          end: end,
          category: category,
        );

        programs.putIfAbsent(channelId, () => []).add(program);
      }

      // 按开始时间排序
      for (final programList in programs.values) {
        programList.sort((a, b) => a.start.compareTo(b.start));
      }

      return {
        'programs': programs,
        'channelNames': channelNames,
        'nameIndex': nameIndex,
      };
    } catch (e) {
      return null;
    }
  }

  /// 规范化频道名称（静态版本，用于 isolate）
  /// 参考台标服务的匹配逻辑
  static String _normalizeNameStatic(String name) {
    String normalized = name.toUpperCase();

    // 1. 先去除空格、横线、下划线（保留 + 号），统一格式
    normalized = normalized.replaceAll(RegExp(r'[-\s_]+'), '');

    // 2. 特殊处理：CCTV01 -> CCTV1
    normalized = normalized.replaceAllMapped(
      RegExp(r'CCTV0*(\d+)'),
      (match) => 'CCTV${match.group(1)}',
    );

    // 3. 去除英文后缀
    normalized = normalized.replaceAll(RegExp(r'(HD|4K|8K|FHD|UHD|SD)'), '');

    // 4. 去除中文后缀（匹配末尾的修饰词）
    normalized = normalized.replaceAll(
      RegExp(r'(高清|超清|蓝光|高码率|低码率|标清|频道)$'),
      '',
    );

    // 5. 特殊处理 CCTV 频道：去除中文描述（如 CCTV1综合 -> CCTV1）
    normalized = normalized.replaceAllMapped(
      RegExp(r'(CCTV\d+\+?)[\u4e00-\u9fa5]+'),
      (match) => match.group(1)!,
    );

    // 6. 特殊处理：保留"卫视"
    if (!normalized.endsWith('卫视') && name.toUpperCase().contains('卫视')) {
      // 如果原名包含卫视但被去掉了，加回来
      final wsMatch = RegExp(r'(.+?)卫视')
          .firstMatch(name.toUpperCase().replaceAll(RegExp(r'[-\s_]+'), ''));
      if (wsMatch != null) {
        normalized = '${wsMatch.group(1)!}卫视';
      }
    }

    // 7. 去除卫视后缀的修饰词
    normalized = normalized.replaceAll(
      RegExp(r'(卫视)(高清|超清)$'),
      r'$1',
    );

    return normalized;
  }

  static DateTime? _parseDateTimeStatic(String str) {
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

  /// 智能解码内容，支持 UTF-8 和 GBK (Static version for isolate)
  static String _decodeContentStatic(List<int> bytes) {
    // 先尝试 UTF-8
    try {
      final content = utf8.decode(bytes);
      // 检查是否有乱码（常见的 UTF-8 解码 GBK 的特征）
      if (!content.contains('') && !_hasGarbledChineseStatic(content)) {
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

  static bool _hasGarbledChineseStatic(String content) {
    // 检查是否有常见的乱码模式
    final garbledPatterns = [
      'å',
      'ä',
      'ã',
      'æ',
      'ç',
      'è',
      'é',
      'ê',
      'ë',
      'ì',
      'í',
      'î',
      'ï'
    ];
    int count = 0;
    for (final pattern in garbledPatterns) {
      if (content.contains(pattern)) count++;
    }
    // 如果有多个这样的字符，可能是乱码
    return count > 3;
  }

  void clear() {
    _programs.clear();
    _channelNames.clear();
    _nameIndex.clear();
    _lookupCache.clear();
    _lastUpdate = null;
  }
}
