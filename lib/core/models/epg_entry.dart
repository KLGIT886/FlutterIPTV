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
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
          : DateTime.now(),
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
  
  /// Check if this program is currently airing
  bool get isLive {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }
  
  /// Check if this program has ended
  bool get hasEnded => DateTime.now().isAfter(endTime);
  
  /// Check if this program is upcoming
  bool get isUpcoming => DateTime.now().isBefore(startTime);
  
  /// Get the duration of the program
  Duration get duration => endTime.difference(startTime);
  
  /// Get the progress percentage (0.0 - 1.0) if currently live
  double get progress {
    if (!isLive) return hasEnded ? 1.0 : 0.0;
    final now = DateTime.now();
    final elapsed = now.difference(startTime);
    return elapsed.inSeconds / duration.inSeconds;
  }
  
  @override
  String toString() => 'EpgEntry(title: $title, start: $startTime, end: $endTime)';
}
