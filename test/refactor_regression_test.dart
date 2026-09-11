import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_iptv/core/models/channel.dart';
import 'package:flutter_iptv/core/player/mpv_tuner.dart';
import 'package:flutter_iptv/core/services/epg_program.dart';
import 'package:flutter_iptv/core/services/epg_xmltv_parser.dart';
import 'package:flutter_iptv/features/player/utils/catchup_url_builder.dart';
import 'package:flutter_iptv/features/player/utils/epg_time_utils.dart';

/// 拆分重构的回归测试：锁住"只搬不改"的关键纯逻辑。
///
/// 覆盖 B1-1（回看 URL 构建）、B1-3（EPG 名称规范化/模型）、
/// B2-12（EPG 时间工具）、P2-1（MpvTuner 静态判定）。
/// 这些在重构中被移动/合并，最容易因疏忽改变行为，故用测试固定。
void main() {
  // ---------- B1-1: buildCatchupUrl ----------
  group('B1-1 buildCatchupUrl（从 player_screen 抽出的纯函数）', () {
    final program = EpgProgram(
      channelId: 'cctv1',
      title: '新闻联播',
      start: DateTime(2024, 1, 1, 19, 0),
      end: DateTime(2024, 1, 1, 19, 30),
    );

    Channel baseChannel({String? catchup, String? catchupSource}) => Channel(
          playlistId: 1,
          name: 'CCTV-1',
          url: 'http://example.com/live',
          catchup: catchup,
          catchupSource: catchupSource,
        );

    test('未配置 catchupSource 时返回 null', () {
      expect(buildCatchupUrl(baseChannel(catchupSource: null), program), isNull);
    });

    test('\${start} 渲染为 ISO8601 UTC（带 Z 后缀）', () {
      final url = buildCatchupUrl(
          baseChannel(catchupSource: 'http://vod/?start=\${start}'), program);
      expect(url, contains('start='));
      expect(RegExp(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z').hasMatch(url!), isTrue);
      // 不应残留未替换的占位符
      expect(url.contains('\${start}'), isFalse);
    });

    test('\${utc}/\${utcend} 渲染为 Unix 秒级时间戳', () {
      final sec = program.start.toUtc().millisecondsSinceEpoch ~/ 1000;
      final endSec = program.end.toUtc().millisecondsSinceEpoch ~/ 1000;
      final url = buildCatchupUrl(
        baseChannel(catchupSource: 'http://vod/?b=\${utc}&e=\${utcend}'),
        program,
      );
      expect(url, contains('b=$sec'));
      expect(url, contains('e=$endSec'));
    });

    test('\${duration} 为节目时长秒数', () {
      final url = buildCatchupUrl(
        baseChannel(catchupSource: 'http://vod/?d=\${duration}'),
        program,
      );
      expect(url, contains('d=1800')); // 30 分钟
    });

    test('append 模式：把解析后的模板拼到直播 URL 末尾', () {
      final url = buildCatchupUrl(
        baseChannel(
          catchup: 'append',
          catchupSource: '&starttime=\${utc}&endtime=\${utcend}',
        ),
        program,
      );
      expect(url, startsWith('http://example.com/live'));
      expect(url, contains('&starttime='));
      expect(url, contains('&endtime='));
    });

    test('自定义日期格式 \${(b)yyyyMMddHHmmss} 被替换', () {
      final url = buildCatchupUrl(
        baseChannel(catchupSource: 'http://vod/\${(b)yyyyMMddHHmmss}.ts'),
        program,
      );
      expect(url!.contains('\${('), isFalse);
      expect(RegExp(r'/\d{14}\.ts$').hasMatch(url), isTrue);
    });

    // ---- rtp2httpd 规范补充：|UTC 后缀 / YmdHMS 短格式 / (b|e)timestamp ----

    test('rtp2httpd: \${(b)yyyyMMdd|UTC} 支持 |UTC 后缀并输出 UTC', () {
      final url = buildCatchupUrl(
        baseChannel(catchupSource: 'http://vod/?d=\${(b)yyyyMMdd|UTC}'),
        program,
      );
      expect(url!.contains('\${'), isFalse, reason: '不应残留占位符');
      expect(url.contains('|UTC'), isFalse, reason: '|UTC 应被剔除');
      final u = program.start.toUtc();
      final expectDay = '${u.year.toString().padLeft(4, '0')}'
          '${u.month.toString().padLeft(2, '0')}'
          '${u.day.toString().padLeft(2, '0')}';
      expect(url, contains('d=$expectDay'));
    });

    test('rtp2httpd: 短格式 {(b)YmdHMS}（本地）渲染为 14 位数字', () {
      final url = buildCatchupUrl(
        baseChannel(catchupSource: 'http://vod/{(b)YmdHMS}.ts'),
        program,
      );
      expect(url!.contains('{'), isFalse, reason: '不应残留大括号占位符');
      expect(RegExp(r'/\d{14}\.ts$').hasMatch(url), isTrue);
    });

    test('rtp2httpd: 短格式 + |UTC = {(b)YmdHMS|UTC}', () {
      final url = buildCatchupUrl(
        baseChannel(catchupSource: 'http://vod/{(b)YmdHMS|UTC}.ts'),
        program,
      );
      final u = program.start.toUtc();
      final expect14 = '${u.year.toString().padLeft(4, '0')}'
          '${u.month.toString().padLeft(2, '0')}'
          '${u.day.toString().padLeft(2, '0')}'
          '${u.hour.toString().padLeft(2, '0')}'
          '${u.minute.toString().padLeft(2, '0')}'
          '${u.second.toString().padLeft(2, '0')}';
      expect(url, contains(expect14));
    });

    test('rtp2httpd: \${(b)timestamp} / \${(e)timestamp} 输出 Unix 秒', () {
      final startSec = program.start.toUtc().millisecondsSinceEpoch ~/ 1000;
      final endSec = program.end.toUtc().millisecondsSinceEpoch ~/ 1000;
      final url = buildCatchupUrl(
        baseChannel(
            catchupSource: 'http://vod/?s=\${(b)timestamp}&e=\${(e)timestamp}'),
        program,
      );
      expect(url, contains('s=$startSec'));
      expect(url, contains('e=$endSec'));
    });

    test('rtp2httpd: {utc:YmdHMS} 短格式；{utc:yyyyMMdd} 长格式', () {
      final shortUrl = buildCatchupUrl(
        baseChannel(catchupSource: 'http://vod/{utc:YmdHMS}'),
        program,
      );
      expect(RegExp(r'/\d{14}$').hasMatch(shortUrl!), isTrue);

      final longUrl = buildCatchupUrl(
        baseChannel(catchupSource: 'http://vod/{utc:yyyyMMdd}'),
        program,
      );
      expect(RegExp(r'/\d{8}$').hasMatch(longUrl!), isTrue);
    });

    test('回归: {utc:HHmm} 仍按 ICU 时:分（不被误判为短格式 时:月）', () {
      final url = buildCatchupUrl(
        baseChannel(catchupSource: 'http://vod/{utc:HHmm}'),
        program,
      );
      final u = program.start.toUtc();
      final expectHm = '${u.hour.toString().padLeft(2, '0')}'
          '${u.minute.toString().padLeft(2, '0')}';
      expect(RegExp(r'/\d{4}$').hasMatch(url!), isTrue);
      expect(url, endsWith('/$expectHm'));
    });
  });

  // ---------- P2-1: MpvTuner 静态判定 ----------
  group('P2-1 MpvTuner（单屏/分屏共用的 mpv 调优）', () {
    test('isFccSource 识别 fcc 关键字（忽略大小写与 \$ 后缀标签）', () {
      expect(
        MpvTuner.isFccSource(
            'http://192.168.5.1/rtp/239.11.0.24:5140?fcc=1.2.3.4:8027'),
        isTrue,
      );
      expect(MpvTuner.isFccSource('http://host/FCC/1.ts'), isTrue);
      expect(MpvTuner.isFccSource('http://host/1.m3u8'), isFalse);
      // $ 之后是频道名标签，应被剔除后再判定
      expect(MpvTuner.isFccSource('http://host/1.m3u8\$fcc频道'), isFalse);
    });

    test('configuredHwdecMode：软解优先返回 no', () {
      expect(
        MpvTuner.configuredHwdecMode(
            software: true, windowsHwdecMode: 'd3d11va'),
        'no',
      );
      expect(
        MpvTuner.configuredHwdecMode(
            software: false, windowsHwdecMode: 'd3d11va'),
        'd3d11va',
      );
      expect(
        MpvTuner.configuredHwdecMode(
            software: false, windowsHwdecMode: 'dxva2'),
        'dxva2',
      );
      expect(
        MpvTuner.configuredHwdecMode(
            software: false, windowsHwdecMode: 'auto-copy'),
        'auto-copy',
      );
      // 未知值回落到更安全的 auto-safe
      expect(
        MpvTuner.configuredHwdecMode(software: false, windowsHwdecMode: 'x'),
        'auto-safe',
      );
    });
  });

  // ---------- B1-3: EPG 名称规范化 ----------
  group('B1-3 normalizeChannelName（EPG 频道名规范化）', () {
    test('CCTV 去中文后缀与前导零', () {
      expect(normalizeChannelName('CCTV1综合'), 'CCTV1');
      expect(normalizeChannelName('CCTV01'), 'CCTV1');
      expect(normalizeChannelName('CCTV-1'), 'CCTV1');
    });

    test('4K/8K 不因分辨率后缀剥离而塌陷', () {
      expect(normalizeChannelName('CCTV4K'), 'CCTV4K');
      expect(normalizeChannelName('CCTV8K'), 'CCTV8K');
    });

    test('大小写与分隔符归一', () {
      expect(normalizeChannelName('hunanstv'), 'HUNANSTV');
      expect(normalizeChannelName('HUNAN STV'), 'HUNANSTV');
    });

    test('保留"卫视"并去掉"高清"等后缀修饰词', () {
      expect(normalizeChannelName('湖南卫视高清'), '湖南卫视');
      expect(normalizeChannelName('湖南卫视'), '湖南卫视');
    });
  });

  // ---------- B2-12: EPG 时间/状态工具 ----------
  group('B2-12 EPG 时间工具（从 interactive_epg_widget 抽出）', () {
    test('isSameDay 只比较年月日', () {
      expect(isSameDay(DateTime(2024, 1, 1, 8), DateTime(2024, 1, 1, 23)), isTrue);
      expect(isSameDay(DateTime(2024, 1, 1), DateTime(2024, 1, 2)), isFalse);
    });

    test('weekdayLabel 返回中文星期', () {
      expect(weekdayLabel(DateTime(2024, 1, 1)), '周一'); // 周一
      expect(weekdayLabel(DateTime(2024, 1, 7)), '周日'); // 周日
    });

    test('programStatus 判定 已播/直播中/未播', () {
      final now = DateTime.now();
      expect(
        programStatus(EpgProgram(
          channelId: 'c',
          title: 't',
          start: now.subtract(const Duration(minutes: 30)),
          end: now.subtract(const Duration(minutes: 10)),
        )),
        ProgramStatus.past,
      );
      expect(
        programStatus(EpgProgram(
          channelId: 'c',
          title: 't',
          start: now.subtract(const Duration(minutes: 5)),
          end: now.add(const Duration(minutes: 25)),
        )),
        ProgramStatus.live,
      );
      expect(
        programStatus(EpgProgram(
          channelId: 'c',
          title: 't',
          start: now.add(const Duration(hours: 1)),
          end: now.add(const Duration(hours: 2)),
        )),
        ProgramStatus.future,
      );
    });

    test('isWithinCatchupRange：未设置视为不限，设置后按天判定', () {
      final now = DateTime.now();
      final recent = EpgProgram(
        channelId: 'c',
        title: 't',
        start: now.subtract(const Duration(days: 2)),
        end: now.subtract(const Duration(days: 2)),
      );
      final old = EpgProgram(
        channelId: 'c',
        title: 't',
        start: now.subtract(const Duration(days: 30)),
        end: now.subtract(const Duration(days: 30)),
      );
      expect(isWithinCatchupRange(recent, null), isTrue);
      expect(isWithinCatchupRange(recent, 7), isTrue);
      expect(isWithinCatchupRange(old, 7), isFalse);
    });
  });
}
