import 'dart:convert';
import 'dart:io';
import 'package:xml/xml.dart';

import 'epg_program.dart';

/// CCTV*K 通道（如 CCTV4K/CCTV8K）的 K 哨兵：规范化期间用它暂代 K，
/// 避免被分辨率后缀剥离逻辑误删，最终再还原为 K。
const String _cctvKSentinel = '\uE000';

/// 在后台 isolate 中解析 XMLTV 内容。
/// 返回非 null 的 map：成功时含 programs/channelNames/nameIndex 键；
/// 失败时含 'error' 键（值为具体原因），由调用方透传，避免静默返回 null。
///
/// 该函数为顶层函数，可直接作为 [compute] 的入口在后台 isolate 执行。
Map<String, dynamic> parseXmlTvInBackground(Map<String, dynamic> data) {
  try {
    final bytes = data['bytes'] as List<int>;
    final isGzip = data['isGzip'] as bool;

    String content;
    if (isGzip) {
      final decompressed = GZipCodec().decode(bytes);
      content = decodeXmlTvContent(decompressed);
    } else {
      content = decodeXmlTvContent(bytes);
    }

    final document = XmlDocument.parse(content);
    final tv = document.findElements('tv').firstOrNull;
    if (tv == null) {
      return {'error': 'EPG XML 缺少 <tv> 根节点，无法解析节目单'};
    }

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
      final normId = normalizeChannelName(id);

      // 支持两种格式：
      // 1. <channel id="11"><display-name>CCTV1</display-name></channel>
      // 2. <channel id="11" display-name="CCTV1"></channel>
      var displayName =
          channel.findElements('display-name').firstOrNull?.innerText;
      displayName ??= channel.getAttribute('display-name');

      if (displayName != null) {
        channelNames[normId] = displayName;
        // 同一显示名可能对应多个频道 id，全部加入候选列表
        final nameKey = normalizeChannelName(displayName);
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
      final channelId = normalizeChannelName(rawChannelId);

      final start = parseXmlTvDateTime(startStr);
      final end = parseXmlTvDateTime(stopStr);
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
    // 解析异常不再静默：返回带 error 的 map，由调用方透传并 log.e。
    return {'error': 'EPG XML 解析异常：$e'};
  }
}

/// 规范化频道名称，用于解析与智能匹配。
/// 参考台标服务的匹配逻辑。
String normalizeChannelName(String name) {
  String normalized = name.toUpperCase();

  // 1. 先去除空格、横线、下划线（保留 + 号），统一格式
  normalized = normalized.replaceAll(RegExp(r'[-\s_]+'), '');

  // 2. 特殊处理：CCTV01 -> CCTV1；CCTV*K 通道的 K 先换为哨兵，
  //    防止步骤3把 K 当分辨率后缀剥掉（否则 CCTV4K 与 CCTV8K 都会塌成 CCTV）。
  normalized = normalized.replaceAllMapped(
    RegExp(r'CCTV0*(\d+)K'),
    (match) => 'CCTV${match.group(1)}$_cctvKSentinel',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'CCTV0*(\d+)'),
    (match) => 'CCTV${match.group(1)}',
  );

  // 3. 去除英文后缀。注意：4K/8K 不剥离，超高清分辨率频道
  //    （如 CCTV4K、beijingstv_4k）与标清版本独立，不再共享合并节目单；
  //    仅剥 HD/FHD/UHD/SD。
  normalized = normalized.replaceAll(RegExp(r'(HD|FHD|UHD|SD)'), '');

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

  // 还原 CCTV*K 通道的 K（CCTV4K -> CCTV4K，CCTV8K -> CCTV8K）
  normalized = normalized.replaceAll(_cctvKSentinel, 'K');

  return normalized;
}

/// 解析 XMLTV 的时间（14 位数字 + 可选时区 +HHMM），返回本地时间。
DateTime? parseXmlTvDateTime(String str) {
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

/// 智能解码内容，支持 UTF-8 和 GBK（GBK 用 Latin1 探测 + allowMalformed 兜底）。
String decodeXmlTvContent(List<int> bytes) {
  // 先尝试 UTF-8
  try {
    final content = utf8.decode(bytes);
    // 检查是否有乱码（常见的 UTF-8 解码 GBK 的特征）
    if (!content.contains('\uFEFF') && !hasGarbledChinese(content)) {
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

bool hasGarbledChinese(String content) {
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
