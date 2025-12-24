/// Represents an IPTV channel
class Channel {
  final int? id;
  final int playlistId;
  final String name;
  final String url;
  final String? logoUrl;
  final String? groupName;
  final String? epgId;
  final bool isActive;
  final DateTime createdAt;

  // Runtime properties (not stored in database)
  bool isFavorite;
  bool isCurrentlyPlaying;

  Channel({
    this.id,
    required this.playlistId,
    required this.name,
    required this.url,
    this.logoUrl,
    this.groupName,
    this.epgId,
    this.isActive = true,
    DateTime? createdAt,
    this.isFavorite = false,
    this.isCurrentlyPlaying = false,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Channel.fromMap(Map<String, dynamic> map) {
    final logoUrl = map['logo_url'] as String?;

    return Channel(
      id: map['id'] as int?,
      playlistId: map['playlist_id'] as int,
      name: map['name'] as String,
      url: map['url'] as String,
      logoUrl: logoUrl,
      groupName: map['group_name'] as String?,
      epgId: map['epg_id'] as String?,
      isActive: (map['is_active'] as int?) == 1,
      createdAt: map['created_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'playlist_id': playlistId,
      'name': name,
      'url': url,
      'logo_url': logoUrl,
      'group_name': groupName,
      'epg_id': epgId,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  Channel copyWith({
    int? id,
    int? playlistId,
    String? name,
    String? url,
    String? logoUrl,
    String? groupName,
    String? epgId,
    bool? isActive,
    DateTime? createdAt,
    bool? isFavorite,
    bool? isCurrentlyPlaying,
  }) {
    return Channel(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      name: name ?? this.name,
      url: url ?? this.url,
      logoUrl: logoUrl ?? this.logoUrl,
      groupName: groupName ?? this.groupName,
      epgId: epgId ?? this.epgId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
      isCurrentlyPlaying: isCurrentlyPlaying ?? this.isCurrentlyPlaying,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Channel && other.id == id && other.url == url;
  }

  @override
  int get hashCode => id.hashCode ^ url.hashCode;

  @override
  String toString() => 'Channel(id: $id, name: $name, group: $groupName)';
}
