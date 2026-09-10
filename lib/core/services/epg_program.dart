/// EPG 节目信息（纯值对象，无外部依赖，可被 UI 层独立引用）。
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
