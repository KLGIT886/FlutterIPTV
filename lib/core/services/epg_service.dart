import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import './service_locator.dart';
import './epg_program.dart';
import './epg_xmltv_parser.dart';

// 保持向后兼容：原先各 UI 文件从 epg_service.dart 引用 EpgProgram，
// 现模型已迁至 epg_program.dart，这里再导出以免改动所有调用点的 import。
export './epg_program.dart';

/// 当前节目缓存项。
///
/// 节目按开始时间升序，因此只需记住命中位置，下一次查询优先在该位置附近验证，
/// 命中时是 O(1)，未命中（节目已结束）时从该位置继续二分，避免全量遍历。
class _CurrentProgramCache {
  final int version;
  final EpgProgram? program;

  const _CurrentProgramCache({
    required this.version,
    required this.program,
  });
}

/// 可用日历日列表缓存项。
class _AvailableDatesCache {
  final int version;
  final List<DateTime> dates;
  const _AvailableDatesCache({required this.version, required this.dates});
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

  // 数据版本号：_programs 每次整体替换时递增，用于让"当前节目"缓存失效。
  // （_lookupCache 只缓存命中结果，这里需要额外的失效信号）
  int _dataVersion = 0;

  // 当前节目缓存 (channelKey -> 缓存项)，避免 build 路径对整张节目单做线性扫描
  final Map<String, _CurrentProgramCache> _currentProgramCache = {};

  // 可用日历日列表缓存（按频道 key），随 _dataVersion 失效（P2-4）
  final Map<String, _AvailableDatesCache> _availableDatesCache = {};

  DateTime? _lastUpdate;
  bool _isLoading = false;
  String? _lastError;

  bool get isLoading => _isLoading;
  DateTime? get lastUpdate => _lastUpdate;
  /// 最近一次加载失败的具体原因（解析异常 / HTTP 错误 / 数据格式错误）。
  /// 用于在 UI 上展示"加载失败"之外的真实错误，避免用户只见笼统提示。
  String? get lastError => _lastError;

  /// 重叠节目回扫窗口：节目通常连续不重叠，极少数源会出现长节目横跨多个短节目，
  /// 此时需向前回扫才能取到与原线性扫描一致（开始时间最早）的覆盖节目。
  static const int _maxOverlapScan = 32;

  /// 二分查找：返回第一个 start 严格晚于 [time] 的索引（即 upperBound）。
  static int _upperBound(List<EpgProgram> programs, DateTime time) {
    var lo = 0;
    var hi = programs.length;
    while (lo < hi) {
      final mid = lo + ((hi - lo) >> 1);
      if (programs[mid].start.isAfter(time)) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }

  /// 获取频道当前节目
  ///
  /// 该方法在频道卡片 / 播放器控件的 build 路径上被逐项调用，
  /// 因此用二分 + 缓存替代全量遍历（节目列表已按 start 升序）。
  EpgProgram? getCurrentProgram(String? channelId, String? channelName) {
    final programs = _findPrograms(channelId, channelName);
    if (programs == null || programs.isEmpty) return null;

    final now = DateTime.now();
    final cacheKey = '${channelId ?? ''}_${channelName ?? ''}';

    // 命中缓存且节目仍在进行中 → O(1) 返回
    final cached = _currentProgramCache[cacheKey];
    if (cached != null && cached.version == _dataVersion) {
      final cachedProgram = cached.program;
      if (cachedProgram != null &&
          !now.isBefore(cachedProgram.start) &&
          now.isBefore(cachedProgram.end)) {
        return cachedProgram;
      }
    }

    // 定位最后一个 start <= now 的节目，再在回扫窗口内取开始时间最早的覆盖者
    var idx = _upperBound(programs, now) - 1;
    final backLimit = idx - _maxOverlapScan;
    EpgProgram? found;
    while (idx >= 0 && idx > backLimit) {
      final program = programs[idx];
      if (now.isAfter(program.start) && now.isBefore(program.end)) {
        found = program;
      }
      idx--;
    }

    _currentProgramCache[cacheKey] = _CurrentProgramCache(
      version: _dataVersion,
      program: found,
    );
    return found;
  }

  /// 获取频道下一个节目
  EpgProgram? getNextProgram(String? channelId, String? channelName) {
    final programs = _findPrograms(channelId, channelName);
    if (programs == null || programs.isEmpty) return null;

    final now = DateTime.now();
    final idx = _upperBound(programs, now);
    return idx < programs.length ? programs[idx] : null;
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

  /// 获取某频道 EPG 数据覆盖的日历日列表（按天去重、升序）。
  /// 日期窗口完全由数据反推：最早节目日 = 可回看的最早一天，
  /// 最晚节目日 = 预览/可看的最晚一天。无节目数据时返回单天（今天）。
  List<DateTime> getAvailableDates(
      String? channelId, String? channelName) {
    final programs = _findPrograms(channelId, channelName);
    if (programs == null || programs.isEmpty) return [DateTime.now()];

    // 命中缓存（且数据版本未变）直接返回，避免每次面板重建都 O(n) 遍历全部节目（P2-4）
    final cacheKey = '${channelId ?? ''}_${channelName ?? ''}';
    final cached = _availableDatesCache[cacheKey];
    if (cached != null && cached.version == _dataVersion) {
      return cached.dates;
    }

    DateTime min = programs.first.start;
    for (final p in programs) {
      if (p.start.isBefore(min)) min = p.start;
    }

    final minDay = DateTime(min.year, min.month, min.day);
    // 窗口末天取“最晚节目 start 的日历日”，而非最晚 end：末尾档节目常为
    // 22:00~00:00 跨到次日凌晨，若按 end 取日历日会把下一日也算进来，
    // 而 getProgramsForDate 对恰好 00:00 结束的节目不会算进该日，从而多出空页面。
    // 节目归属其 start 日，跨天收尾不构成新的一天。programs 已按 start 升序排序。
    final lastStart = programs.last.start;
    final maxDay =
        DateTime(lastStart.year, lastStart.month, lastStart.day);

    final dates = <DateTime>[];
    for (var d = minDay;
        !d.isAfter(maxDay);
        d = DateTime(d.year, d.month, d.day + 1)) {
      dates.add(d);
    }

    _availableDatesCache[cacheKey] = _AvailableDatesCache(
      version: _dataVersion,
      dates: dates,
    );
    return dates;
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

    // 先用 channelId 查找。
    // _programs 的 key 在解析时已被规范化（见 _parseXmlTvInBackground），
    // 因此这里必须用同样的规范化后再比较，否则 'hunanstv' 永远匹配不到 'HUNANSTV'，
    // 只能退化到名称索引；当 XMLTV 只有 <programme> 而没有 <channel> 节点时
    // _nameIndex 为空，会直接导致该频道永远显示"暂无节目单"。
    if (channelId != null && channelId.isNotEmpty) {
      final normalizedId = normalizeChannelName(channelId);
      if (_programs.containsKey(normalizedId)) {
        _lookupCache[cacheKey] = normalizedId;
        return _programs[normalizedId];
      }
    }

    // 用频道名称索引快速查找
    if (channelName != null && channelName.isNotEmpty) {
      final normalizedName = _normalizeName(channelName);

      // 4K/8K 频道回落策略：先用含分辨率后缀的名字精确匹配自有节目单
      // （如 BEIJINGSTV4K / CCTV4K），若该频道无任一候选有节目数据，
      // 再回落到剥掉分辨率后缀的标清版本（BEIJINGSTV / CCTV4），
      // 避免 4K 源缺节目单时空白。其他频道不触发回落。
      String? foundId = _findNameIndexId(normalizedName);
      if (foundId == null) {
        final fallbackName =
            _stripResolutionSuffix(normalizedName);
        if (fallbackName != normalizedName) {
          foundId = _findNameIndexId(fallbackName);
        }
      }

      if (foundId != null) {
        _lookupCache[cacheKey] = foundId;
        return _programs[foundId];
      }

      // 尝试用 channelId 作为名称查找
      if (channelId != null && channelId.isNotEmpty) {
        final normalizedId = _normalizeName(channelId);
        foundId = _findNameIndexId(normalizedId);
        if (foundId == null) {
          final fallbackId = _stripResolutionSuffix(normalizedId);
          if (fallbackId != normalizedId) {
            foundId = _findNameIndexId(fallbackId);
          }
        }
        if (foundId != null) {
          _lookupCache[cacheKey] = foundId;
          return _programs[foundId];
        }
      }
    }

    // 未匹配：不缓存 null 结果，数据就绪后重新查询即可命中
    return null;
  }

  /// 在名称索引中查找第一个真正有节目数据的频道 id。
  /// 未命中或所有候选均无节目数据时返回 null。
  String? _findNameIndexId(String normalizedName) {
    if (!_nameIndex.containsKey(normalizedName)) return null;
    for (final foundId in _nameIndex[normalizedName]!) {
      final list = _programs[foundId];
      if (list != null && list.isNotEmpty) return foundId;
    }
    return null;
  }

  /// 剥离分辨率后缀（供 4K/8K 频道回落使用）。仅剥离，不做其它规范化。
  String _stripResolutionSuffix(String normalized) {
    return normalized.replaceAll(RegExp(r'(HD|4K|8K|FHD|UHD|SD)'), '');
  }

  /// 规范化频道名称，用于智能匹配。
  /// 复用解析器的同一套规范化逻辑（epg_xmltv_parser.normalizeChannelName），
  /// 消除此前两份逐行重复实现可能产生的漂移。
  String _normalizeName(String name) => normalizeChannelName(name);

  /// 从 URL 加载 EPG 数据
  Future<bool> loadFromUrl(String url) async {
    if (_isLoading) return false;
    _isLoading = true;
    _lastError = null;

    try {
      ServiceLocator.log.d('EPG: Loading from $url');

      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode != 200) {
        _lastError = 'EPG HTTP 请求失败：状态码 ${response.statusCode}';
        ServiceLocator.log.e('EPG: HTTP error ${response.statusCode}',
            tag: 'EPG');
        return false;
      }

      // 在后台 isolate 中解析 XML，避免阻塞 UI
      final computeData = {
        'bytes': response.bodyBytes,
        'isGzip': url.endsWith('.gz'),
      };

      final result = await compute(parseXmlTvInBackground, computeData);

      // 解析失败时 _parseXmlTvInBackground 返回带 'error' 键的 map（而非 null），
      // 这里透传具体原因，避免用户只见笼统的"加载失败"。
      if (result['error'] != null) {
        _lastError = result['error'] as String;
        ServiceLocator.log.e('EPG: 解析失败: $_lastError', tag: 'EPG');
        return false;
      }

      // compute 返回后已回到主 isolate，直接同步应用数据。
      // 不能用 scheduleMicrotask 异步写入：否则 loadFromUrl 返回 true 时
      // 数据尚未就绪，调用方随后查询会拿到空数据（节目单看似加载不全）。
      // 先清空查询缓存，避免用旧数据的频道 id 映射去匹配新数据。
      _lookupCache.clear();
      _currentProgramCache.clear();
      _availableDatesCache.clear();
      _dataVersion++;
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
    } catch (e, st) {
      _lastError = 'EPG 加载异常：$e';
      ServiceLocator.log.e('EPG: Error loading', error: e, stackTrace: st);
      return false;
    } finally {
      _isLoading = false;
    }
  }

  /// 仅测试使用：从 XML 字符串加载 EPG，走与 [loadFromUrl] 相同的解析管道
  /// （[_parseXmlTvInBackground]），但不发起网络请求、不启用后台 isolate。
  /// 便于在单元测试中直接注入数据并验证查询/日期窗口/规范化逻辑。
  /// 生产代码不调用此方法。
  @visibleForTesting
  Future<bool> loadFromXmlString(String xml) async {
    _lastError = null;
    final result = parseXmlTvInBackground({
      'bytes': utf8.encode(xml),
      'isGzip': false,
    });
    if (result['error'] != null) {
      _lastError = result['error'] as String;
      return false;
    }

    // 复制 loadFromUrl 成功路径：先清空旧缓存，再注入解析结果。
    _lookupCache.clear();
    _currentProgramCache.clear();
    _availableDatesCache.clear();
    _dataVersion++;
    _programs.clear();
    _channelNames.clear();
    _nameIndex.clear();

    _programs.addAll(result['programs'] as Map<String, List<EpgProgram>>);
    _channelNames.addAll(result['channelNames'] as Map<String, String>);
    _nameIndex.addAll(result['nameIndex'] as Map<String, List<String>>);
    _lastUpdate = DateTime.now();
    return true;
  }

  void clear() {
    _programs.clear();
    _channelNames.clear();
    _nameIndex.clear();
    _lookupCache.clear();
    _currentProgramCache.clear();
    _dataVersion++;
    _lastUpdate = null;
  }
}
