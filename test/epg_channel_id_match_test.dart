import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_iptv/core/services/epg_service.dart';

/// 验证 EPG 的 channelId 匹配路径。
///
/// `_programs` 的 key 在解析时已被规范化，查询侧若用原始 id 直查将永远命中不了
/// （'hunanstv' 匹配不到 'HUNANSTV'）。当 XMLTV 只有 `<programme>` 而没有
/// `<channel>` 节点时，名称索引为空，该频道会永久显示"暂无节目单"。
void main() {
  tearDown(() => EpgService().clear());

  String xmlTime(DateTime t) {
    final u = t.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${u.year}${two(u.month)}${two(u.day)}'
        '${two(u.hour)}${two(u.minute)}${two(u.second)} +0000';
  }

  test('channel 节点 id 与 programme channel 大小写不一致时仍能匹配', () async {
    const xml = '''
<tv>
  <channel id="HUNANSTV"><display-name>湖南卫视</display-name></channel>
  <programme channel="hunanstv" start="20260904100000 +0800" stop="20260904110000 +0800">
    <title>节目A</title>
  </programme>
</tv>
''';
    await EpgService().loadFromXmlString(xml);

    final programs = EpgService().getProgramsForDate(
      'hunanstv',
      null,
      DateTime(2026, 9, 4),
    );

    expect(programs, isNotEmpty, reason: '小写 id 应命中规范化为 HUNANSTV 的节目表');
    expect(programs.first.title, '节目A');
  });

  test('XMLTV 只有 programme 没有 channel 节点时也能匹配', () async {
    const xml = '''
<tv>
  <programme channel="CCTV1" start="20260904100000 +0800" stop="20260904110000 +0800">
    <title>新闻联播</title>
  </programme>
</tv>
''';
    await EpgService().loadFromXmlString(xml);

    // 没有 <channel> 节点 → 名称索引为空，只有规范化直查能命中
    final programs = EpgService().getProgramsForDate(
      'CCTV1',
      null,
      DateTime(2026, 9, 4),
    );

    expect(programs, isNotEmpty);
    expect(programs.first.title, '新闻联播');
  });

  test('带符号的 channelId（如 CCTV-1）可匹配', () async {
    const xml = '''
<tv>
  <programme channel="CCTV-1" start="20260904100000 +0800" stop="20260904110000 +0800">
    <title>节目B</title>
  </programme>
</tv>
''';
    await EpgService().loadFromXmlString(xml);

    final programs = EpgService().getProgramsForDate(
      'CCTV-1',
      null,
      DateTime(2026, 9, 4),
    );

    expect(programs, isNotEmpty);
    expect(programs.first.title, '节目B');
  });

  test('getCurrentProgram / getNextProgram 二分结果与时间顺序一致', () async {
    final now = DateTime.now();
    final xml = '''
<tv>
  <channel id="CH1"><display-name>CH1</display-name></channel>
  <programme channel="CH1" start="${xmlTime(now.subtract(const Duration(hours: 3)))}" stop="${xmlTime(now.subtract(const Duration(hours: 1)))}">
    <title>已结束</title>
  </programme>
  <programme channel="CH1" start="${xmlTime(now.subtract(const Duration(minutes: 30)))}" stop="${xmlTime(now.add(const Duration(minutes: 30)))}">
    <title>正在播出</title>
  </programme>
  <programme channel="CH1" start="${xmlTime(now.add(const Duration(hours: 1)))}" stop="${xmlTime(now.add(const Duration(hours: 2)))}">
    <title>即将播出</title>
  </programme>
</tv>
''';
    await EpgService().loadFromXmlString(xml);

    expect(EpgService().getCurrentProgram('CH1', null)?.title, '正在播出');
    expect(EpgService().getNextProgram('CH1', null)?.title, '即将播出');
  });

  test('节目单重新加载后当前节目缓存失效', () async {
    final now = DateTime.now();
    String buildXml(String title) => '''
<tv>
  <channel id="CH1"><display-name>CH1</display-name></channel>
  <programme channel="CH1" start="${xmlTime(now.subtract(const Duration(minutes: 30)))}" stop="${xmlTime(now.add(const Duration(minutes: 30)))}">
    <title>$title</title>
  </programme>
</tv>
''';

    await EpgService().loadFromXmlString(buildXml('第一版'));
    expect(EpgService().getCurrentProgram('CH1', null)?.title, '第一版');

    await EpgService().loadFromXmlString(buildXml('第二版'));
    expect(
      EpgService().getCurrentProgram('CH1', null)?.title,
      '第二版',
      reason: '数据版本变化后不得返回旧数据的缓存结果',
    );
  });

  test('无匹配频道时返回空而非抛异常', () async {
    const xml = '''
<tv>
  <programme channel="CH1" start="20260904100000 +0800" stop="20260904110000 +0800">
    <title>节目</title>
  </programme>
</tv>
''';
    await EpgService().loadFromXmlString(xml);

    expect(EpgService().getProgramsForDate('NOPE', null, DateTime(2026, 9, 4)), isEmpty);
    expect(EpgService().getCurrentProgram('NOPE', null), isNull);
    expect(EpgService().getNextProgram('NOPE', null), isNull);
  });
}
