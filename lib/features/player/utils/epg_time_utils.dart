import '../../../core/services/epg_program.dart';

/// EPG 面板使用的时间/状态纯函数工具（从 interactive_epg_widget 抽出）。

/// 节目状态：已播出 / 直播中 / 未播出。
enum ProgramStatus { past, live, future }

/// 两个日期是否为同一天。
bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// 返回中文星期标签（如 '周一'）。
String weekdayLabel(DateTime date) {
  const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return weekdays[date.weekday - 1];
}

/// 依据当前时间判断节目状态。
ProgramStatus programStatus(EpgProgram program) {
  final now = DateTime.now();
  if (now.isAfter(program.start) && now.isBefore(program.end)) {
    return ProgramStatus.live;
  } else if (now.isAfter(program.end)) {
    return ProgramStatus.past;
  } else {
    return ProgramStatus.future;
  }
}

/// 节目是否落在回看窗口内（catchupDays 为空视为不限制）。
bool isWithinCatchupRange(EpgProgram program, int? catchupDays) {
  if (catchupDays == null) {
    return true; // Default to true if not specified? Or false?
  }
  // If catchupDays is set, check if program start is within days.
  // Assuming catchupDays means "last N days".
  final diff = DateTime.now().difference(program.start).inDays;
  return diff <= catchupDays;
}
