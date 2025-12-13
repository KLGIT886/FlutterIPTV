/// Represents a channel group/category
class ChannelGroup {
  final String name;
  final int channelCount;
  final String? iconUrl;
  
  const ChannelGroup({
    required this.name,
    this.channelCount = 0,
    this.iconUrl,
  });
  
  ChannelGroup copyWith({
    String? name,
    int? channelCount,
    String? iconUrl,
  }) {
    return ChannelGroup(
      name: name ?? this.name,
      channelCount: channelCount ?? this.channelCount,
      iconUrl: iconUrl ?? this.iconUrl,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChannelGroup && other.name == name;
  }
  
  @override
  int get hashCode => name.hashCode;
  
  @override
  String toString() => 'ChannelGroup(name: $name, channels: $channelCount)';
}
