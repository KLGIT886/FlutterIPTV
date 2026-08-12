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

  // 频道名称索引 (normalizedName -> channelId 候选列表) 用于快速查找
  // 同一显示名可能对应多个频道 id（如"湖南卫视"=HUNANSTV 与 HUNANWEISHI50P），
  // 用列表保存全部候选，避免被后解析的重复频道覆盖。
  final Map<String, List<String>> _nameIndex = {};

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
    return getProgramsForDate(channelId, channelName, DateTime.now());
  }

  /// 获取指定日期的节目列表
  List<EpgProgram> getProgramsForDate(
      String? channelId, String? channelName, DateTime date) {
    final programs = _findPrograms(channelId, channelName);
    if (programs == null) return [];

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return programs.where((p) {
      // Program interval: [start, end]
      // Day interval: [startOfDay, endOfDay]
      // Overlap if start < endOfDay AND end > startOfDay
      return p.start.isBefore(endOfDay) && p.end.isAfter(startOfDay);
    }).toList();
  }

  List<EpgProgram>? _findPrograms(String? channelId, String? channelName) {
    // 生成缓存 key
    final cacheKey = '${channelId ?? ''}_${channelName ?? ''}';

    // 诊断：湖南卫视匹配过程
    // if (channelName != null && channelName.contains('湖南')) {
    //   final normKey = _normalizeName('HUNANSTV');
    //   ServiceLocator.log.d(
    //       '_findPrograms 输入: channelId=$channelId, channelName=$channelName');
    //   ServiceLocator.log.d(
    //       '  _nameIndex 含"湖南卫视"=${_nameIndex.containsKey(_normalizeName('湖南卫视'))}, '
    //       '含"HUNANSTV"=${_nameIndex.containsKey(normKey)}');
    //   ServiceLocator.log.d(
    //       '  _programs 含"HUNANSTV"=${_programs.containsKey(normKey)}, '
    //       '_nameIndex大小=${_nameIndex.length}, _programs大小=${_programs.length}');
    //   ServiceLocator.log.d(
    //       '  normalize(湖南卫视)=${_normalizeName('湖南卫视')}, _nameIndex[湖南卫视]=${_nameIndex[_normalizeName('湖南卫视')]}');
    // }

    // 检查缓存（仅缓存"命中"的映射，不缓存"未找到"的 null 结果）。
    // 原实现把 null 缓存进 _lookupCache，导致 EPG 数据加载完成前被查询过的
    // 频道，在数据就绪后仍被旧的空缓存锁死，一直显示"暂无节目单"。
    if (_lookupCache.containsKey(cacheKey)) {
      final cachedId = _lookupCache[cacheKey];
      if (cachedId != null && _programs.containsKey(cachedId)) {
        return _programs[cachedId];
      }
      // 命中缓存但 id 已失效（数据被替换），当作未命中重新匹配
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
        // 同一显示名可能映射到多个频道 id（如"湖南卫视"=HUNANSTV 与
        // HUNANWEISHI50P），遍历候选，优先返回真正有节目数据的那个。
        for (final foundId in _nameIndex[normalizedName]!) {
          final list = _programs[foundId];
          if (list != null && list.isNotEmpty) {
            _lookupCache[cacheKey] = foundId;
            return list;
          }
        }
        // 所有候选均无节目数据，返回 null（不缓存，数据就绪后可重新命中）
        return null;
      }

      // 尝试用 channelId 作为名称查找
      if (channelId != null && channelId.isNotEmpty) {
        final normalizedId = _normalizeName(channelId);
        if (_nameIndex.containsKey(normalizedId)) {
          for (final foundId in _nameIndex[normalizedId]!) {
            final list = _programs[foundId];
            if (list != null && list.isNotEmpty) {
              _lookupCache[cacheKey] = foundId;
              return list;
            }
          }
          return null;
        }
      }
    }

    // 未匹配：不缓存 null 结果，数据就绪后重新查询即可命中
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
        // compute 返回后已回到主 isolate，直接同步应用数据。
        // 不能用 scheduleMicrotask 异步写入：否则 loadFromUrl 返回 true 时
        // 数据尚未就绪，调用方随后查询会拿到空数据（节目单看似加载不全）。
        // 先清空查询缓存，避免用旧数据的频道 id 映射去匹配新数据。
        _lookupCache.clear();
        _programs.clear();
        _channelNames.clear();
        _nameIndex.clear();

        _programs.addAll(result['programs'] as Map<String, List<EpgProgram>>);
        _channelNames.addAll(result['channelNames'] as Map<String, String>);
        _nameIndex.addAll(result['nameIndex'] as Map<String, List<String>>);

        _lastUpdate = DateTime.now();
        ServiceLocator.log.d(
            'EPG: Loaded ${_programs.length} channels, ${_programs.values.fold(0, (sum, list) => sum + list.length)} programs');

        // 诊断日志：打印湖南卫视等频道的节目数与日期范围，定位"节目单被截断"
        // for (final id in const ['hunanstv', 'HUNANSTV', 'jiangxistv']) {
        //   final list = _programs[id];
        //   if (list == null || list.isEmpty) continue;
        //   final minStart = list
        //       .map((p) => p.start)
        //       .reduce((a, b) => a.isBefore(b) ? a : b);
        //   final maxEnd = list
        //       .map((p) => p.end)
        //       .reduce((a, b) => a.isAfter(b) ? a : b);
        //   ServiceLocator.log.d(
        //       'EPG诊断: id=$id 共${list.length}条, 最早=$minStart, 最晚=$maxEnd');
        //   // 按天分布（programme 开始日期）
        //   final byDay = <String, int>{};
        //   for (final p in list) {
        //     final d = p.start;
        //     final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        //     byDay[key] = (byDay[key] ?? 0) + 1;
        //   }
        //   final sorted = byDay.entries.toList()
        //     ..sort((a, b) => a.key.compareTo(b.key));
        //   ServiceLocator.log.d(
        //       'EPG诊断: id=$id 按天分布: ${sorted.map((e) => '${e.key}=${e.value}').join(', ')}');
        // }
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
      final nameIndex = <String, List<String>>{};

      // 解析频道
      for (final channel in tv.findElements('channel')) {
        final id = channel.getAttribute('id');
        if (id == null) continue;

        // 统一规范化频道 id，保证与 <programme channel="..."> 的 key 一致。
        // 某些 EPG 源中 <channel id="HUNANSTV"> 与 <programme channel="hunanstv">
        // 大小写不一致，若不做规范化，nameIndex 指向的 id 在 _programs 中找不到，
        // 导致该频道节目单一直返回 0 条。
        final normId = _normalizeNameStatic(id);

        // 支持两种格式：
        // 1. <channel id="11"><display-name>CCTV1</display-name></channel>
        // 2. <channel id="11" display-name="CCTV1"></channel>
        var displayName =
            channel.findElements('display-name').firstOrNull?.innerText;
        displayName ??= channel.getAttribute('display-name');

        if (displayName != null) {
          channelNames[normId] = displayName;
          // 同一显示名可能对应多个频道 id，全部加入候选列表
          final nameKey = _normalizeNameStatic(displayName);
          nameIndex.putIfAbsent(nameKey, () => <String>[]).add(normId);
          if (nameKey != normId) {
            nameIndex.putIfAbsent(normId, () => <String>[]).add(normId);
          }
        }
      }

      // 解析节目 (支持 programme 和 program 两种标签)
      final programmes = tv.findElements('programme').toList();
      programmes.addAll(tv.findElements('program'));

      for (final programme in programmes) {
        final rawChannelId = programme.getAttribute('channel');
        final startStr = programme.getAttribute('start');
        final stopStr = programme.getAttribute('stop');

        if (rawChannelId == null || startStr == null || stopStr == null) {
          continue;
        }

        // 与 <channel id> 使用相同的规范化，解决大小写不一致导致的匹配失败
        final channelId = _normalizeNameStatic(rawChannelId);

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
      // Match 14 digits, optional space, optional timezone (+/-HHMM)
      final match = RegExp(r'(\d{14})\s*([+-]\d{4})?').firstMatch(str);
      if (match == null) return null;

      final dateStr = match.group(1)!;
      final tzStr = match.group(2);

      int year = int.parse(dateStr.substring(0, 4));
      int month = int.parse(dateStr.substring(4, 6));
      int day = int.parse(dateStr.substring(6, 8));
      int hour = int.parse(dateStr.substring(8, 10));
      int minute = int.parse(dateStr.substring(10, 12));
      int second = int.parse(dateStr.substring(12, 14));

      // Create UTC time first
      DateTime dt = DateTime.utc(year, month, day, hour, minute, second);

      if (tzStr != null) {
        // Parse timezone offset
        final sign = tzStr.startsWith('+') ? 1 : -1;
        final tzHour = int.parse(tzStr.substring(1, 3));
        final tzMinute = int.parse(tzStr.substring(3, 5));
        final offset = Duration(hours: tzHour, minutes: tzMinute) * sign;

        // Apply offset to get true UTC
        dt = dt.subtract(offset);
      }

      // Convert to local time
      return dt.toLocal();
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
