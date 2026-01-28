/// Represents a channel logo mapping
class ChannelLogo {
  final int? id;
  final String channelName;
  final String logoUrl;
  final String? searchKeys; // Comma-separated search keywords
  final DateTime createdAt;

  ChannelLogo({
    this.id,
    required this.channelName,
    required this.logoUrl,
    this.searchKeys,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ChannelLogo.fromMap(Map<String, dynamic> map) {
    return ChannelLogo(
      id: map['id'] as int?,
      channelName: map['channel_name'] as String,
      logoUrl: map['logo_url'] as String,
      searchKeys: map['search_keys'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'channel_name': channelName,
      'logo_url': logoUrl,
      'search_keys': searchKeys,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() => 'ChannelLogo(name: $channelName, url: $logoUrl)';
}
