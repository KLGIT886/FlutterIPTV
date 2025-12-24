/// Represents an IPTV playlist (M3U/M3U8 source)
class Playlist {
  final int? id;
  final String name;
  final String? url;
  final String? filePath;
  final bool isActive;
  final DateTime? lastUpdated;
  final DateTime createdAt;

  // Runtime properties
  int channelCount;
  int groupCount;

  Playlist({
    this.id,
    required this.name,
    this.url,
    this.filePath,
    this.isActive = true,
    this.lastUpdated,
    DateTime? createdAt,
    this.channelCount = 0,
    this.groupCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Playlist.fromMap(Map<String, dynamic> map) {
    return Playlist(
      id: map['id'] as int?,
      name: map['name'] as String,
      url: map['url'] as String?,
      filePath: map['file_path'] as String?,
      isActive: (map['is_active'] as int?) == 1,
      lastUpdated: map['last_updated'] != null ? DateTime.fromMillisecondsSinceEpoch(map['last_updated'] as int) : null,
      createdAt: map['created_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'url': url,
      'file_path': filePath,
      'is_active': isActive ? 1 : 0,
      'last_updated': lastUpdated?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  Playlist copyWith({
    int? id,
    String? name,
    String? url,
    String? filePath,
    bool? isActive,
    DateTime? lastUpdated,
    DateTime? createdAt,
    int? channelCount,
    int? groupCount,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      filePath: filePath ?? this.filePath,
      isActive: isActive ?? this.isActive,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      createdAt: createdAt ?? this.createdAt,
      channelCount: channelCount ?? this.channelCount,
      groupCount: groupCount ?? this.groupCount,
    );
  }

  /// Check if this is a remote playlist (URL-based)
  bool get isRemote => url != null && url!.isNotEmpty;

  /// Check if this is a local playlist (file-based)
  bool get isLocal => filePath != null && filePath!.isNotEmpty;

  /// Check if this is a temporary playlist (imported via QR)
  bool get isTemporary => filePath != null && filePath!.contains('temp') && filePath!.contains('playlist_');

  /// Get the source path (URL or file path)
  String get sourcePath => url ?? filePath ?? '';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Playlist && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Playlist(id: $id, name: $name, channels: $channelCount)';
}
