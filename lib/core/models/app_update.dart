class AppUpdate {
  final String version;
  final String tagName;
  final String releaseNotes;
  final String downloadUrl;
  final DateTime publishedAt;
  final bool isPrerelease;

  AppUpdate({
    required this.version,
    required this.tagName,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.publishedAt,
    this.isPrerelease = false,
  });

  factory AppUpdate.fromJson(Map<String, dynamic> json) {
    // 从tagName中提取版本号，移除'v'前缀
    String version = json['tag_name'] ?? '0.0.0';
    if (version.startsWith('v')) {
      version = version.substring(1);
    }

    // 获取发布说明
    String releaseNotes = json['body'] ?? '';

    // 获取发布时间
    DateTime publishedAt =
        DateTime.tryParse(json['published_at'] ?? '') ?? DateTime.now();

    // 获取下载URL
    String downloadUrl = '';
    if (json['assets'] != null &&
        json['assets'] is List &&
        json['assets'].isNotEmpty) {
      downloadUrl = json['assets'][0]['browser_download_url'] ?? '';
    }

    return AppUpdate(
      version: version,
      tagName: json['tag_name'] ?? '',
      releaseNotes: releaseNotes,
      downloadUrl: downloadUrl,
      publishedAt: publishedAt,
      isPrerelease: json['prerelease'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'tagName': tagName,
      'releaseNotes': releaseNotes,
      'downloadUrl': downloadUrl,
      'publishedAt': publishedAt.toIso8601String(),
      'isPrerelease': isPrerelease,
    };
  }

  @override
  String toString() {
    return 'AppUpdate(version: $version, tagName: $tagName, downloadUrl: $downloadUrl, publishedAt: $publishedAt)';
  }
}
