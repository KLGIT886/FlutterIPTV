import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_iptv/core/services/epg_service.dart';

/// 验证 EpgService 的纯逻辑：日期窗口推导、节目归属、频道规范化与 4K/8K 回落。
/// 通过公开的 [EpgService.loadFromXmlString] 注入真实解析管道的产物，
/// 再对查询 API 断言行为，避免复制实现逻辑导致测试失真。
void main() {
  // 每个用例前重置单例状态，避免用例间相互污染。
  tearDown(() => EpgService().clear());

  test('P1-9: 畸形 EPG（缺少 <tv> 根节点）应透传具体错误而非静默返回', () async {
    const xml = '<notTv></notTv>';
    final ok = await EpgService().loadFromXmlString(xml);

    expect(ok, isFalse, reason: '畸形 XML 应加载失败');
    final err = EpgService().lastError;
    expect(err, isNotNull, reason: '应暴露具体解析原因，而非笼统的"加载失败"');
    expect(err, contains('tv'), reason: '错误应指出缺少 <tv> 根节点');
  });

  test('getAvailableDates: 跨天节目(22点->次日0点)不产生次日空页', () async {
    const xml = '''
<tv>
  <channel id="CCTV1"><display-name>CCTV1</display-name></channel>
  <programme channel="CCTV1" start="20260904220000 +0800" stop="20260905000000 +0800" title=""
  />
</tv>
''';
    await EpgService().loadFromXmlString(xml);

    final dates = EpgService().getAvailableDates('CCTV1', null);

    // 日期窗口应只覆盖「各节目 start 所在日历日」，不含由 end 跨到次日的空页。
    final expectedDays = {DateTime(2026, 9, 4)};
    expect(dates.length, expectedDays.length,
        reason: '跨天节目不应把窗口末天推到次日');
    for (final d in dates) {
      expect(expectedDays.contains(d), isTrue,
          reason: '出现仅由 end 推导出的多余日期: $d');
    }
  });

  test('getAvailableDates: 多节目跨两天窗口覆盖各自 start 日历日', () async {
    const xml = '''
<tv>
  <channel id="CCTV1"><display-name>CCTV1</display-name></channel>
  <programme channel="CCTV1" start="20260904100000 +0800" stop="20260904110000 +0800"
  />
  <programme channel="CCTV1" start="20260905200000 +0800" stop="20260905230000 +0800"
  />
</tv>
''';
    await EpgService().loadFromXmlString(xml);

    final dates = EpgService().getAvailableDates('CCTV1', null);

    expect(dates.length, 2);
    expect(dates, contains(DateTime(2026, 9, 4)));
    expect(dates, contains(DateTime(2026, 9, 5)));
  });

  test('getProgramsForDate: 跨天节目归属于其 start 日而非结束日', () async {
    const xml = '''
<tv>
  <channel id="CCTV1"><display-name>CCTV1</display-name></channel>
  <programme channel="CCTV1" start="20260904220000 +0800" stop="20260905000000 +0800"
  />
</tv>
''';
    await EpgService().loadFromXmlString(xml);

    final onStartDay = EpgService()
        .getProgramsForDate('CCTV1', null, DateTime(2026, 9, 4));
    expect(onStartDay.length, 1, reason: '22点节目应出现在其 start 当天');

    final onEndDay = EpgService()
        .getProgramsForDate('CCTV1', null, DateTime(2026, 9, 5));
    expect(onEndDay.length, 0,
        reason: '次日 00:00 结束的节目不应算进次日页面（避免空节目/错位）');
  });

  test('4K 回落: 真实同频道分辨率变体回落标清', () async {
    // 只提供标清北京卫视 beijingstv 的节目单；beijingstv_4k 与其为同一
    // 频道的 4K 变体，无自有节目单时回落标清。注意：CCTV4K 这类频道号
    // 紧贴数字+ K 的形态不属于分辨率变体，与本回落逻辑无关。
    const xml = '''
<tv>
  <channel id="beijingstv"><display-name>北京卫视</display-name></channel>
  <programme channel="beijingstv" start="20260904120000 +0800" stop="20260904130000 +0800"
  />
</tv>
''';
    final service = EpgService();
    await service.loadFromXmlString(xml);

    // 正查：确认数据注入链路正常（经名字索引定位频道节目单）。
    final direct = service.getProgramsForDate('', '北京卫视', DateTime(2026, 9, 4));
    expect(direct.length, 1, reason: '正查北京卫视应命中');

    // 回落：4K 变体无自有节目单，应回落到标清 beijingstv。
    final programs = service.getProgramsForDate('', 'beijingstv_4k', DateTime(2026, 9, 4));
    expect(programs.length, 1, reason: 'beijingstv_4k 应回落标清 beijingstv 的节目');
  });

  test('规范化: 频道 id 大小写/零填充不一致仍能匹配', () async {
    // channel id="CCTV01" 显示名，programme 用 "cctv1"（小写）。
    const xml = '''
<tv>
  <channel id="CCTV01"><display-name>CCTV1</display-name></channel>
  <programme channel="cctv1" start="20260904180000 +0800" stop="20260904190000 +0800"
  />
</tv>
''';
    final service = EpgService();
    await service.loadFromXmlString(xml);

    // 经名字索引查询：显示名 CCTV1 应定位到解析后同为 CCTV1 的节目单。
    final programs =
        service.getProgramsForDate('CCTV01', 'CCTV1', DateTime(2026, 9, 4));

    expect(programs.length, 1,
        reason: 'CCTV01/CCTV1 与 cctv1 应归一化后匹配为同一频道');
  });

  test('getProgramsForDate: 无节目数据返回空列表', () async {
    const xml = '''
<tv>
  <channel id="CCTV1"><display-name>CCTV1</display-name></channel>
</tv>
''';
    await EpgService().loadFromXmlString(xml);

    final programs =
        EpgService().getProgramsForDate('CCTV1', null, DateTime(2026, 9, 4));

    expect(programs, isEmpty);
  });
}