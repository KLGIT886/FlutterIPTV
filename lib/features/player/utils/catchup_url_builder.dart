import 'package:intl/intl.dart';

import '../../../core/models/channel.dart';
import '../../../core/services/epg_service.dart';

/// 根据频道配置与节目时间，生成回看（catchup / replay）播放 URL。
///
/// 支持主流 IPTV 回看占位符规范：
/// - `${start}/${stop}/${end}`：ISO 8601（UTC）
/// - `${utc}/${utcend}/${timestamp}/${duration}/${offset}`：Unix 秒（Kodi pvr.iptvsimple / rtp2httpd）
/// - `${(b|e)(u)?yyyyMMddHHmmss}` 及 `{(b|e)...}`：自定义格式（本地/UTC）
/// - `{Y}/{m}/{d}/{H}/{M}/{S}`：时间分量
///
/// 返回 null 表示该频道不支持回看（未配置 catchupSource）。
/// 该函数为纯函数，不依赖任何实例状态，便于单独测试与复用。
String? buildCatchupUrl(Channel channel, EpgProgram program) {
  if (channel.catchupSource == null) return null;

  // catchup 模式：default（占位符替换）、append（URL 追加）、shift（偏移）
  final catchupMode = channel.catchup?.toLowerCase() ?? 'default';

  // IMPORTANT: program.start and program.end are LOCAL time (converted in EPG parser)
  // They match what user sees in EPG UI.
  final startLocal = program.start;
  final endLocal = program.end;
  final startUtc = startLocal.toUtc();
  final endUtc = endLocal.toUtc();

  // ISO 8601 format (UTC): yyyy-MM-ddTHH:mm:ssZ - for ${start}, ${stop}, ${end}
  final startIso = startUtc.toIso8601String();
  final startIsoClean = startIso.replaceAll(RegExp(r'\.\d+Z$'), 'Z');
  final endIso = endUtc.toIso8601String();
  final endIsoClean = endIso.replaceAll(RegExp(r'\.\d+Z$'), 'Z');

  // Unix 秒级 UTC 时间戳（Kodi pvr.iptvsimple 事实标准）for ${utc}, ${utcend}, {utc}, {utcend}
  final startSec = startUtc.millisecondsSinceEpoch ~/ 1000;
  final endSec = endUtc.millisecondsSinceEpoch ~/ 1000;
  // 时长（秒）for ${duration}
  final durationSec = endUtc.difference(startUtc).inSeconds;

  // 当前时刻（UTC）— 对齐 rtp2httpd 的 ${lutc}/${now}/${timestamp}/${offset}
  final now = DateTime.now().toUtc();
  final nowSec = now.millisecondsSinceEpoch ~/ 1000;
  final nowIso = now.toIso8601String().replaceAll(RegExp(r'\.\d+Z$'), 'Z');
  // 距节目开始的偏移（秒）for ${offset}
  final offsetSec = nowSec - startSec;

  var url = channel.catchupSource!;

  // Step 1: Handle custom date format patterns with timezone support
  // Pattern variations:
  //   ${(b)yyyyMMddHHmmss}        -> begin/start, LOCAL time (matches EPG display)
  //   ${(e)yyyyMMddHHmmss}        -> end, LOCAL time
  //   ${(bu)yyyyMMddHHmmss}       -> begin/start, UTC time (explicit UTC, prefix u)
  //   ${(eu)yyyyMMddHHmmss}       -> end, UTC time
  //   ${(b)yyyyMMddHHmmss:UTC}    -> begin/start, UTC time (Kodi :UTC suffix)
  //   ${(e)yyyyMMddHHmmss:UTC}    -> end, UTC time
  //   ${(B)...} / ${(E)...}       -> uppercase variants as aliases
  // 匹配前缀 u 或后缀 :UTC 两种时区标记，并将 `:UTC` 从格式串中剔除
  final customFormatRegex =
      RegExp(r'\$\{\(([bBeE])([uU]?)\)([A-Za-z:"\u0027]+)(?::UTC)?\}');
  final customMatches = customFormatRegex.allMatches(url);
  for (final match in customMatches) {
    final timeMarker = match.group(1)!.toLowerCase(); // 'b' or 'e'
    final tzMarker = match.group(2)!.toLowerCase(); // 'u' or ''
    // 格式串可能自带 :UTC 后缀（如 yyyyMMddHHmmss:UTC），需剔除后再格式化
    var formatStr = match.group(3)!;
    final hasUtcSuffix = formatStr.endsWith(':UTC');
    if (hasUtcSuffix) {
      formatStr = formatStr.substring(0, formatStr.length - 4);
    }

    // Choose local or UTC datetime: 前缀 u 或后缀 :UTC 均按 UTC 处理
    final useUtc = tzMarker == 'u' || hasUtcSuffix;
    DateTime dateTime;
    if (useUtc) {
      // Explicit UTC requested
      dateTime = (timeMarker == 'b') ? startUtc : endUtc;
    } else {
      // Default: use LOCAL time to match EPG display
      dateTime = (timeMarker == 'b') ? startLocal : endLocal;
    }

    try {
      final formatter = DateFormat(formatStr);
      final formatted = formatter.format(dateTime);
      url = url.replaceFirst(match.group(0)!, formatted);
    } catch (_) {
      // If DateFormat fails, skip this replacement (keep original pattern)
    }
  }

  // Also handle brace-only version: {(b)yyyyMMddHHmmss}, {(bu)yyyyMMddHHmmss}, {(b)...:UTC}
  final braceFormatRegex = RegExp(r'\{\(([bBeE])([uU]?)\)([^}]+)\}');
  final braceMatches = braceFormatRegex.allMatches(url);
  for (final match in braceMatches) {
    final timeMarker = match.group(1)!.toLowerCase();
    final tzMarker = match.group(2)!.toLowerCase();
    var formatStr = match.group(3)!;
    final hasUtcSuffix = formatStr.endsWith(':UTC');
    if (hasUtcSuffix) {
      formatStr = formatStr.substring(0, formatStr.length - 4);
    }
    final useUtc = tzMarker == 'u' || hasUtcSuffix;
    DateTime dateTime;
    if (useUtc) {
      dateTime = (timeMarker == 'b') ? startUtc : endUtc;
    } else {
      dateTime = (timeMarker == 'b') ? startLocal : endLocal;
    }
    try {
      final formatter = DateFormat(formatStr);
      final formatted = formatter.format(dateTime);
      url = url.replaceFirst(match.group(0)!, formatted);
    } catch (_) {}
  }

  // Step 2: Handle standard ${start}/${stop}/${end} patterns. 保持 ISO 8601 (UTC) 兼容
  // ISO format with 'Z' suffix always means UTC - this is the standard behavior
  url = url.replaceAll(RegExp(r'\$\{start\}'), startIsoClean);
  url = url.replaceAll(RegExp(r'\$\{stop\}'), endIsoClean);
  url = url.replaceAll(RegExp(r'\$\{end\}'), endIsoClean);

  // Handle {start}/{stop}/{end}
  url = url.replaceAll(RegExp(r'\{start\}'), startIsoClean);
  url = url.replaceAll(RegExp(r'\{stop\}'), endIsoClean);
  url = url.replaceAll(RegExp(r'\{end\}'), endIsoClean);

  // Step 2.4: 对齐 rtp2httpd 的「关键字:格式」占位符 — 用指定格式串渲染时间
  //   ${utc:yyyyMMdd} / {utc:yyyyMMdd}   -> 节目开始时间（UTC）
  //   ${utcend:yyyyMMdd} / {utcend:...}  -> 节目结束时间（UTC）
  //   ${start:格式} / ${end:格式}         -> 开始/结束（UTC）
  //   ${lutc:格式} / ${now:格式} / ${timestamp:格式} -> 当前时刻（UTC）
  void applyKeywordFormat(RegExp regex) {
    for (final match in regex.allMatches(url).toList()) {
      final keyword = match.group(1)!.toLowerCase();
      final fmt = match.group(2)!;
      DateTime? target;
      if (keyword == 'utc' ||
          keyword == 'start' ||
          keyword == 'yyyy' ||
          keyword == 'MM' ||
          keyword == 'dd' ||
          keyword == 'HH' ||
          keyword == 'mm' ||
          keyword == 'ss') {
        target = startUtc;
      } else if (keyword == 'utcend' || keyword == 'end') {
        target = endUtc;
      } else if (keyword == 'lutc' ||
          keyword == 'now' ||
          keyword == 'timestamp') {
        target = now;
      }
      if (target == null) continue;
      try {
        final formatted = DateFormat(fmt).format(target);
        url = url.replaceFirst(match.group(0)!, formatted);
      } catch (_) {}
    }
  }

  applyKeywordFormat(RegExp(r'\$\{(\w+):([^}]+)\}'));
  applyKeywordFormat(RegExp(r'\{(\w+):([^}]+)\}'));

  // Step 2.5: 行业标准占位符（Kodi pvr.iptvsimple 规范）— Unix 秒级 UTC 时间戳
  //   ${utc}        -> 节目开始时间（Unix 秒，UTC）
  //   ${utcend}     -> 节目结束时间（Unix 秒，UTC）
  //   ${timestamp}  -> 当前时刻（Unix 秒，UTC）— 对齐 rtp2httpd
  //   ${duration}   -> 节目时长（秒）
  //   ${offset}     -> 当前时刻 - 节目开始（秒）— 对齐 rtp2httpd
  //   ${lutc}/${now}-> 当前时刻（完整 ISO+Z）— 对齐 rtp2httpd
  url = url.replaceAll(RegExp(r'\$\{utc\}'), startSec.toString());
  url = url.replaceAll(RegExp(r'\$\{utcend\}'), endSec.toString());
  url = url.replaceAll(RegExp(r'\$\{timestamp\}'), nowSec.toString());
  url = url.replaceAll(RegExp(r'\$\{duration\}'), durationSec.toString());
  url = url.replaceAll(RegExp(r'\$\{offset\}'), offsetSec.toString());
  url = url.replaceAll(RegExp(r'\$\{lutc\}'), nowIso);
  url = url.replaceAll(RegExp(r'\$\{now\}'), nowIso);
  // 大括号版本
  url = url.replaceAll(RegExp(r'\{utc\}'), startSec.toString());
  url = url.replaceAll(RegExp(r'\{utcend\}'), endSec.toString());
  url = url.replaceAll(RegExp(r'\{timestamp\}'), nowSec.toString());
  url = url.replaceAll(RegExp(r'\{duration\}'), durationSec.toString());
  url = url.replaceAll(RegExp(r'\{offset\}'), offsetSec.toString());
  url = url.replaceAll(RegExp(r'\{lutc\}'), nowIso);
  url = url.replaceAll(RegExp(r'\{now\}'), nowIso);

  // Step 2.6: 时间分量占位符（对齐 rtp2httpd）— 均取节目开始时间（UTC）
  //   长格式：${yyyy}/${MM}/${dd}/${HH}/${mm}/${ss}
  //   短格式（brace-only）：{Y}/{m}/{d}/{H}/{M}/{S}
  final compYear = DateFormat('yyyy').format(startUtc);
  final compMonth = DateFormat('MM').format(startUtc);
  final compDay = DateFormat('dd').format(startUtc);
  final compHour = DateFormat('HH').format(startUtc);
  final compMinute = DateFormat('mm').format(startUtc);
  final compSecond = DateFormat('ss').format(startUtc);
  url = url.replaceAll(RegExp(r'\$\{yyyy\}'), compYear);
  url = url.replaceAll(RegExp(r'\$\{MM\}'), compMonth);
  url = url.replaceAll(RegExp(r'\$\{dd\}'), compDay);
  url = url.replaceAll(RegExp(r'\$\{HH\}'), compHour);
  url = url.replaceAll(RegExp(r'\$\{mm\}'), compMinute);
  url = url.replaceAll(RegExp(r'\$\{ss\}'), compSecond);
  url = url.replaceAll(RegExp(r'\{Y\}'), compYear);
  url = url.replaceAll(RegExp(r'\{m\}'), compMonth);
  url = url.replaceAll(RegExp(r'\{d\}'), compDay);
  url = url.replaceAll(RegExp(r'\{H\}'), compHour);
  url = url.replaceAll(RegExp(r'\{M\}'), compMinute);
  url = url.replaceAll(RegExp(r'\{S\}'), compSecond);

  // Step 3: append 模式 — 在直播 URL 上追加 catchup-source 参数片段
  // Xtream 规范：catchup="append" 时，catchup-source 是待追加的参数模板
  // （如 &starttime={utc}&endtime={utcend}），拼接到原始直播地址末尾形成回看 URL。
  // 注意：{utc}/{utcend}/{duration}/{timestamp} 等占位符已由 Step 1/2/2.5 统一替换
  if (catchupMode == 'append') {
    return channel.url + url;
  }

  return url;
}
