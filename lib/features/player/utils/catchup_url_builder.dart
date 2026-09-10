import 'package:intl/intl.dart';

import '../../../core/models/channel.dart';
import '../../../core/services/epg_service.dart';

/// 根据频道配置与节目时间，生成回看（catchup / replay）播放 URL。
///
/// 支持占位符规范（对齐 rtp2httpd `web-player` 文档，并兼容 Kodi/Xtream 常见写法）：
///
/// A. 带 (b)/(e) 的自定义时间格式（`${...}` 与 `{...}` 两种括号）：
///    - `${(b)yyyyMMddHHmmss}`  开始时间，**本地**时间，长格式（ICU：yyyy MM dd HH mm ss）
///    - `${(e)yyyyMMddHHmmss}`  结束时间，本地，长格式
///    - `${(b)yyyyMMdd|UTC}`    开始时间，**UTC**（`|UTC` 后缀，rtp2httpd 规范）
///    - `${(e)yyyyMMdd:UTC}`    结束时间，UTC（`:UTC` 后缀，Kodi 写法，亦兼容）
///    - `${(bu)yyyyMMddHHmmss}` 开始时间，UTC（`(bu)` 前缀，亦兼容）
///    - `{(b)YmdHMS}`           开始时间，本地，**短格式**（Y=年4位 m=月 d=日 H=时 M=分 S=秒）
///    - `{(b)YmdHMS|UTC}`       开始时间，UTC，短格式
///    - `${(b)timestamp}`      开始时间的 Unix 秒（rtp2httpd 规范）
///    - `{(e)timestamp}`       结束时间的 Unix 秒
///
/// B. 关键字占位符：
///    - `${start}/${stop}/${end}`、`{start}/{stop}/{end}`：ISO 8601（UTC）
///    - `${utc}/${utcend}`、`{utc}/{utcend}`：Unix 秒（Kodi/Xtream 事实标准）
///    - `${timestamp}`、`{timestamp}`：当前 Unix 秒
///    - `${lutc}/${now}`、`{lutc}/{now}`：当前时刻 ISO 8601（UTC）
///    - `${duration}/${offset}`：时长 / 距节目开始偏移（秒）
///    - `${utc:格式}`、`{utc:格式}` 等「关键字:格式」：`{}` 支持短格式 `YmdHMS`
///
/// C. 时间分量：`${yyyy}/${MM}/${dd}/${HH}/${mm}/${ss}` 与 `{Y}/{m}/{d}/{H}/{M}/{S}`
///
/// 返回 null 表示该频道不支持回看（未配置 catchupSource）。
/// 该函数为纯函数，不依赖任何实例状态，便于单独测试与复用。
String? buildCatchupUrl(Channel channel, EpgProgram program) {
  if (channel.catchupSource == null) return null;

  // catchup 模式：default（占位符替换）、append（URL 追加）、shift（偏移）
  final catchupMode = channel.catchup?.toLowerCase() ?? 'default';

  // IMPORTANT: program.start / program.end 为本地时间（EPG 解析时已转换），
  // 与用户在 EPG 界面看到的一致。
  final startLocal = program.start;
  final endLocal = program.end;
  final startUtc = startLocal.toUtc();
  final endUtc = endLocal.toUtc();

  // ISO 8601 (UTC)：yyyy-MM-ddTHH:mm:ssZ - for ${start}/${stop}/${end}
  final startIso = startUtc.toIso8601String();
  final startIsoClean = startIso.replaceAll(RegExp(r'\.\d+Z$'), 'Z');
  final endIso = endUtc.toIso8601String();
  final endIsoClean = endIso.replaceAll(RegExp(r'\.\d+Z$'), 'Z');

  // Unix 秒级 UTC 时间戳（Kodi pvr.iptvsimple / Xtream 事实标准）
  final startSec = startUtc.millisecondsSinceEpoch ~/ 1000;
  final endSec = endUtc.millisecondsSinceEpoch ~/ 1000;
  // 时长（秒）
  final durationSec = endUtc.difference(startUtc).inSeconds;

  // 当前时刻（UTC）
  final now = DateTime.now().toUtc();
  final nowSec = now.millisecondsSinceEpoch ~/ 1000;
  final nowIso = now.toIso8601String().replaceAll(RegExp(r'\.\d+Z$'), 'Z');
  // 距节目开始的偏移（秒）
  final offsetSec = nowSec - startSec;

  var url = channel.catchupSource!;

  // ── Step 1: 带 (b)/(e) 的自定义格式（`${...}` 长格式 与 `{...}` 短格式）──
  // 统一处理：可选 `$` 前缀、时区标记（`u` 前缀 / `|UTC` / `:UTC` 后缀）、
  // 以及 `timestamp` 特例（返回 Unix 秒而非格式化文本）。
  final timeFormatRegex = RegExp(r'\$?\{\(([bBeE])([uU]?)\)([^}]+)\}');
  for (final match in timeFormatRegex.allMatches(url).toList()) {
    final timeMarker = match.group(1)!.toLowerCase(); // 'b' or 'e'
    final tzMarker = match.group(2)!.toLowerCase(); // 'u' or ''
    var formatStr = match.group(3)!;

    // 时区标记：`u` 前缀，或 `|UTC` / `:UTC` 后缀（三种写法均视为 UTC）
    var useUtc = tzMarker == 'u';
    if (formatStr.endsWith('|UTC')) {
      useUtc = true;
      formatStr = formatStr.substring(0, formatStr.length - 4);
    } else if (formatStr.endsWith(':UTC')) {
      useUtc = true;
      formatStr = formatStr.substring(0, formatStr.length - 4);
    }

    final base = (timeMarker == 'b') ? startLocal : endLocal;
    final dateTime = useUtc ? base.toUtc() : base;

    final String replacement;
    if (formatStr == 'timestamp') {
      // rtp2httpd：`${(b)timestamp}` / `{(e)timestamp}` → Unix 秒
      replacement = (dateTime.millisecondsSinceEpoch ~/ 1000).toString();
    } else {
      final rendered = _renderCustomFormat(dateTime, formatStr);
      if (rendered == null) continue; // 格式非法：保留原占位符
      replacement = rendered;
    }
    url = url.replaceFirst(match.group(0)!, replacement);
  }

  // ── Step 2: `${start}/${stop}/${end}` 与 `{start}/{stop}/{end}` → ISO 8601 (UTC) ──
  url = url.replaceAll(RegExp(r'\$\{start\}'), startIsoClean);
  url = url.replaceAll(RegExp(r'\$\{stop\}'), endIsoClean);
  url = url.replaceAll(RegExp(r'\$\{end\}'), endIsoClean);
  url = url.replaceAll(RegExp(r'\{start\}'), startIsoClean);
  url = url.replaceAll(RegExp(r'\{stop\}'), endIsoClean);
  url = url.replaceAll(RegExp(r'\{end\}'), endIsoClean);

  // ── Step 3: 「关键字:格式」占位符（`${utc:yyyyMMdd}` / `{utc:YmdHMS}`）──
  // 目标时间均为 UTC；`{}` 括号内支持 rtp2httpd 短格式 `YmdHMS`。
  void applyKeywordFormat(RegExp regex) {
    for (final match in regex.allMatches(url).toList()) {
      final keyword = match.group(1)!.toLowerCase();
      final fmt = match.group(2)!;
      DateTime? target;
      if (keyword == 'utc' || keyword == 'start' || keyword == 'yyyy' ||
          keyword == 'MM' || keyword == 'dd' || keyword == 'HH' ||
          keyword == 'mm' || keyword == 'ss') {
        target = startUtc;
      } else if (keyword == 'utcend' || keyword == 'end') {
        target = endUtc;
      } else if (keyword == 'lutc' || keyword == 'now' ||
          keyword == 'timestamp') {
        target = now;
      }
      if (target == null) continue;
      final rendered = _renderCustomFormat(target, fmt);
      if (rendered == null) continue;
      url = url.replaceFirst(match.group(0)!, rendered);
    }
  }

  applyKeywordFormat(RegExp(r'\$\{(\w+):([^}]+)\}'));
  applyKeywordFormat(RegExp(r'(?<!\$)\{(\w+):([^}]+)\}'));

  // ── Step 4: 裸关键字占位符（Unix 秒 / ISO）──
  //   ${utc}/${utcend}      -> 节目开始/结束时间（Unix 秒，UTC）
  //   ${timestamp}          -> 当前时刻（Unix 秒）
  //   ${duration}/${offset} -> 时长 / 偏移（秒）
  //   ${lutc}/${now}        -> 当前时刻（ISO 8601 UTC）
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

  // ── Step 5: 时间分量占位符（对齐 rtp2httpd）— 取节目开始时间 ──
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

  // ── Step 6: append 模式 — 在直播 URL 上追加 catchup-source 参数片段 ──
  // Xtream 规范：catchup="append" 时，catchup-source 是待追加的参数模板
  // （如 &starttime={utc}&endtime={utcend}），拼接到原始直播地址末尾形成回看 URL。
  if (catchupMode == 'append') {
    return channel.url + url;
  }

  return url;
}

/// rtp2httpd 短格式（`{}` 括号内使用）：仅由这些字母构成时走短格式渲染。
///   Y=年(4位) m=月(2位) d=日(2位) H=时(2位) M=分(2位) S=秒(2位)
final RegExp _shortFormatPattern = RegExp(r'^[YmdHMS]+$');

/// 判断是否为 rtp2httpd 短格式串（如 `YmdHMS`）；否则按 ICU 长格式处理。
bool _isShortFormat(String fmt) => _shortFormatPattern.hasMatch(fmt);

/// 按 rtp2httpd 短格式字母表渲染时间。
String _renderShortFormat(DateTime dt, String fmt) {
  String two(int n) => n.toString().padLeft(2, '0');
  final sb = StringBuffer();
  for (final rune in fmt.runes) {
    switch (String.fromCharCode(rune)) {
      case 'Y':
        sb.write(dt.year.toString().padLeft(4, '0'));
        break;
      case 'm':
        sb.write(two(dt.month));
        break;
      case 'd':
        sb.write(two(dt.day));
        break;
      case 'H':
        sb.write(two(dt.hour));
        break;
      case 'M':
        sb.write(two(dt.minute));
        break;
      case 'S':
        sb.write(two(dt.second));
        break;
      default:
        sb.writeCharCode(rune);
    }
  }
  return sb.toString();
}

/// 渲染自定义格式：短格式（YmdHMS）走专用渲染器，其余按 ICU 长格式（DateFormat）。
/// 返回 null 表示格式非法（调用方应保留原占位符，避免产出坏 URL）。
String? _renderCustomFormat(DateTime dt, String fmt) {
  if (fmt.isEmpty) return null;
  if (_isShortFormat(fmt)) return _renderShortFormat(dt, fmt);
  try {
    return DateFormat(fmt).format(dt);
  } catch (_) {
    return null;
  }
}
