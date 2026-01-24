/// Represents an EPG (Electronic Program Guide) entry
class EpgEntry {
  final int? id;
  final String channelEpgId;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String? category;
  final DateTime createdAt;

  EpgEntry({
    this.id,
    required this.channelEpgId,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.category,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory EpgEntry.fromMap(Map<String, dynamic> map) {
    return EpgEntry(
      id: map['id'] as int?,
      channelEpgId: map['channel_epg_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['start_time'] as int),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['end_time'] as int),
      category: map['category'] as String?,
      createdAt: map['created_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'channel_epg_id': channelEpgId,
      'title': title,
      'description': description,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime.millisecondsSinceEpoch,
      'category': category,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Check if this program is currently airing (based on UTC time)
  bool get isLive {
    final now = DateTime.now().toUtc();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  /// Check if this program has ended (based on UTC time)
  bool get hasEnded => DateTime.now().toUtc().isAfter(endTime);

  /// Check if this program is upcoming (based on UTC time)
  bool get isUpcoming => DateTime.now().toUtc().isBefore(startTime);

  /// Get the duration of the program
  Duration get duration => endTime.difference(startTime);

  /// Get the progress percentage (0.0 - 1.0) if currently live (based on UTC time)
  double get progress {
    final now = DateTime.now().toUtc();
    if (now.isBefore(startTime)) return 0.0;
    if (now.isAfter(endTime)) return 1.0;
    final total = duration.inSeconds;
    final elapsed = now.difference(startTime).inSeconds;
    return elapsed / total;
  }

  /// Convert times to specified timezone (hour offset)
  /// Example: +8 for China Standard Time (Beijing Time)
  DateTime startTimeInTimeZone(int hourOffset) {
    return startTime.add(Duration(hours: hourOffset));
  }

  DateTime endTimeInTimeZone(int hourOffset) {
    return endTime.add(Duration(hours: hourOffset));
  }

  /// Check if program is currently airing (based on specified timezone)
  bool isLiveInTimeZone(int hourOffset) {
    final now = DateTime.now().add(Duration(hours: hourOffset));
    final localStart = startTimeInTimeZone(hourOffset);
    final localEnd = endTimeInTimeZone(hourOffset);
    return now.isAfter(localStart) && now.isBefore(localEnd);
  }

  /// Check if program is upcoming (based on specified timezone)
  bool isUpcomingInTimeZone(int hourOffset) {
    final now = DateTime.now().add(Duration(hours: hourOffset));
    final localStart = startTimeInTimeZone(hourOffset);
    return localStart.isAfter(now);
  }

  @override
  String toString() => 'EpgEntry(title: $title, start: $startTime, end: $endTime)';
}
