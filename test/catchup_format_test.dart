import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

/// 验证 _generateCatchupUrl 中占位符替换逻辑的正确性
/// （与 player_screen.dart 中 Step 1/2/2.5 逻辑保持一致）
void main() {
  // 使用固定时间模拟 EPG 节目（本地时间）
  final startLocal = DateTime(2024, 1, 1, 12, 0, 0); // 本地 12:00
  final endLocal = DateTime(2024, 1, 1, 12, 30, 0); // 本地 12:30
  final startUtc = startLocal.toUtc();
  final endUtc = endLocal.toUtc();

  final startIso = startUtc.toIso8601String();
  final startIsoClean = startIso.replaceAll(RegExp(r'\.\d+Z$'), 'Z');
  final endIso = endUtc.toIso8601String();
  final endIsoClean = endIso.replaceAll(RegExp(r'\.\d+Z$'), 'Z');

  final startSec = startUtc.millisecondsSinceEpoch ~/ 1000;
  final endSec = endUtc.millisecondsSinceEpoch ~/ 1000;
  final durationSec = endUtc.difference(startUtc).inSeconds;

  // 当前时刻（UTC）— 对齐 rtp2httpd 的 ${lutc}/${now}/${timestamp}/${offset}
  final now = DateTime.now().toUtc();
  final nowSec = now.millisecondsSinceEpoch ~/ 1000;
  final nowIso = now.toIso8601String().replaceAll(RegExp(r'\.\d+Z$'), 'Z');
  final offsetSec = nowSec - startSec;

  String replace(String url) {
    var result = url;

    // Step 1: custom format with prefix u or suffix :UTC
    final customFormatRegex =
        RegExp(r'\$\{\(([bBeE])([uU]?)\)([A-Za-z:"\u0027]+)(?::UTC)?\}');
    for (final match in customFormatRegex.allMatches(result)) {
      final timeMarker = match.group(1)!.toLowerCase();
      final tzMarker = match.group(2)!.toLowerCase();
      var formatStr = match.group(3)!;
      final hasUtcSuffix = formatStr.endsWith(':UTC');
      if (hasUtcSuffix) {
        formatStr = formatStr.substring(0, formatStr.length - 4);
      }
      final useUtc = tzMarker == 'u' || hasUtcSuffix;
      final dateTime = useUtc
          ? (timeMarker == 'b' ? startUtc : endUtc)
          : (timeMarker == 'b' ? startLocal : endLocal);
      try {
        final formatted = DateFormat(formatStr).format(dateTime);
        result = result.replaceFirst(match.group(0)!, formatted);
      } catch (_) {}
    }

    // Step 2: \${start}/\${stop}/\${end} ISO
    result = result
        .replaceAll(RegExp(r'\$\{start\}'), startIsoClean)
        .replaceAll(RegExp(r'\$\{stop\}'), endIsoClean)
        .replaceAll(RegExp(r'\$\{end\}'), endIsoClean);

    // Step 2.4: 对齐 rtp2httpd 的「关键字:格式」占位符
    void applyKeywordFormat(RegExp regex) {
      for (final match in regex.allMatches(result).toList()) {
        final keyword = match.group(1)!.toLowerCase();
        final fmt = match.group(2)!;
        DateTime? target;
        if (keyword == 'utc' || keyword == 'start') {
          target = startUtc;
        } else if (keyword == 'utcend' || keyword == 'end') {
          target = endUtc;
        } else if (keyword == 'lutc' || keyword == 'now' || keyword == 'timestamp') {
          target = now;
        }
        if (target == null) continue;
        try {
          final formatted = DateFormat(fmt).format(target);
          result = result.replaceFirst(match.group(0)!, formatted);
        } catch (_) {}
      }
    }
    applyKeywordFormat(RegExp(r'\$\{(\w+):([^}]+)\}'));
    applyKeywordFormat(RegExp(r'\{(\w+):([^}]+)\}'));

    // Step 2.5: standard placeholders
    result = result
        .replaceAll(RegExp(r'\$\{utc\}'), startSec.toString())
        .replaceAll(RegExp(r'\$\{utcend\}'), endSec.toString())
        .replaceAll(RegExp(r'\$\{timestamp\}'), nowSec.toString())
        .replaceAll(RegExp(r'\$\{duration\}'), durationSec.toString())
        .replaceAll(RegExp(r'\$\{offset\}'), offsetSec.toString())
        .replaceAll(RegExp(r'\$\{lutc\}'), nowIso)
        .replaceAll(RegExp(r'\$\{now\}'), nowIso)
        .replaceAll(RegExp(r'\{utc\}'), startSec.toString())
        .replaceAll(RegExp(r'\{utcend\}'), endSec.toString())
        .replaceAll(RegExp(r'\{timestamp\}'), nowSec.toString())
        .replaceAll(RegExp(r'\{duration\}'), durationSec.toString())
        .replaceAll(RegExp(r'\{offset\}'), offsetSec.toString())
        .replaceAll(RegExp(r'\{lutc\}'), nowIso)
        .replaceAll(RegExp(r'\{now\}'), nowIso);

    // Step 2.6: 时间分量占位符（对齐 rtp2httpd）— 取节目开始时间（UTC）
    final compYear = DateFormat('yyyy').format(startUtc);
    final compMonth = DateFormat('MM').format(startUtc);
    final compDay = DateFormat('dd').format(startUtc);
    final compHour = DateFormat('HH').format(startUtc);
    final compMinute = DateFormat('mm').format(startUtc);
    final compSecond = DateFormat('ss').format(startUtc);
    result = result
        .replaceAll(RegExp(r'\$\{yyyy\}'), compYear)
        .replaceAll(RegExp(r'\$\{MM\}'), compMonth)
        .replaceAll(RegExp(r'\$\{dd\}'), compDay)
        .replaceAll(RegExp(r'\$\{HH\}'), compHour)
        .replaceAll(RegExp(r'\$\{mm\}'), compMinute)
        .replaceAll(RegExp(r'\$\{ss\}'), compSecond)
        .replaceAll(RegExp(r'\{Y\}'), compYear)
        .replaceAll(RegExp(r'\{m\}'), compMonth)
        .replaceAll(RegExp(r'\{d\}'), compDay)
        .replaceAll(RegExp(r'\{H\}'), compHour)
        .replaceAll(RegExp(r'\{M\}'), compMinute)
        .replaceAll(RegExp(r'\{S\}'), compSecond);

    return result;
  }

  test('utc/utcend 输出 Unix 秒', () {
    final out = replace('?start=\${utc}&end=\${utcend}');
    expect(out, '?start=$startSec&end=$endSec');
  });

  test('utc 与 utcend 大括号版本', () {
    final out = replace('{utc}-{utcend}');
    expect(out, '$startSec-$endSec');
  });

  test('duration 输出秒数', () {
    final out = replace('?dur=\${duration}');
    expect(out, '?dur=$durationSec');
  });

  test('timestamp 输出当前时刻 Unix 秒（对齐 rtp2httpd）', () {
    final out = replace('?ts=\${timestamp}');
    expect(out, '?ts=$nowSec');
  });

  test('lutc/now 输出当前时刻完整 ISO+Z（对齐 rtp2httpd）', () {
    final out = replace('?a=\${lutc}&b=\${now}&c={now}');
    expect(out, '?a=$nowIso&b=$nowIso&c=$nowIso');
  });

  test('offset 输出现时刻与开始时刻差（秒）', () {
    final out = replace('?o=\${offset}');
    expect(out, '?o=$offsetSec');
  });

  test('utc:格式 用格式串渲染开始时间 UTC', () {
    final out = replace('?start=\${utc:yyyyMMddHHmmss}');
    final expected = DateFormat('yyyyMMddHHmmss').format(startUtc);
    expect(out, '?start=$expected');
  });

  test('utcend:格式 用格式串渲染结束时间 UTC', () {
    final out = replace('?end=\${utcend:yyyyMMdd}');
    final expected = DateFormat('yyyyMMdd').format(endUtc);
    expect(out, '?end=$expected');
  });

  test('关键字:格式 大括号版本', () {
    final out = replace('?s={utc:HH}&e={utcend:HH}');
    final expectedS = DateFormat('HH').format(startUtc);
    final expectedE = DateFormat('HH').format(endUtc);
    expect(out, '?s=$expectedS&e=$expectedE');
  });

  test('时间分量占位符（长格式）取开始时间 UTC', () {
    final out = replace('?y=\${yyyy}&m=\${MM}&d=\${dd}');
    expect(out, '?y=${DateFormat('yyyy').format(startUtc)}&m=${DateFormat('MM').format(startUtc)}&d=${DateFormat('dd').format(startUtc)}');
  });

  test('时间分量占位符（短格式）取开始时间 UTC', () {
    final out = replace('?H={H}&M={M}&S={S}');
    expect(out, '?H=${DateFormat('HH').format(startUtc)}&M=${DateFormat('mm').format(startUtc)}&S=${DateFormat('ss').format(startUtc)}');
  });

  test('(b)yyyyMMddHHmmss:UTC 后缀 UTC', () {
    final out = replace('&Playseek=\${(b)yyyyMMddHHmmss:UTC}');
    final expected = DateFormat('yyyyMMddHHmmss').format(startUtc);
    expect(out, '&Playseek=$expected');
  });

  test('(bu)yyyyMMddHHmmss 前缀 u', () {
    final out = replace('&Playseek=\${(bu)yyyyMMddHHmmss}');
    final expected = DateFormat('yyyyMMddHHmmss').format(startUtc);
    expect(out, '&Playseek=$expected');
  });

  test('(b)yyyyMMddHHmmss 无时区 -> 本地时间', () {
    final out = replace('&Playseek=\${(b)yyyyMMddHHmmss}');
    final expected = DateFormat('yyyyMMddHHmmss').format(startLocal);
    expect(out, '&Playseek=$expected');
  });

  test('start/end ISO UTC', () {
    final out = replace('?start=\${start}&end=\${end}');
    expect(out, '?start=$startIsoClean&end=$endIsoClean');
  });

  test('混合：标准 + 自定义格式', () {
    final out = replace(
        '?starttime=\${utc}&endtime=\${utcend}&ps=\${(b)yyyyMMddHHmmss:UTC}');
    final expectedPs = DateFormat('yyyyMMddHHmmss').format(startUtc);
    expect(out, '?starttime=$startSec&endtime=$endSec&ps=$expectedPs');
  });
}