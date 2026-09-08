/// 播放器界面格式化/解析辅助函数集合。
///
/// 从 player_screen.dart 纯搬移而来，供播放器 UI 复用。
library;

/// 将每秒字节数格式化为可读的速度文本。
String formatSpeed(double bytesPerSecond) {
  if (bytesPerSecond >= 1024 * 1024) {
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  } else if (bytesPerSecond >= 1024) {
    return '${(bytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
  } else {
    return '${bytesPerSecond.toStringAsFixed(0)} B/s';
  }
}

/// 将时长格式化为 HH:MM:SS 或 MM:SS 文本。
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

/// 获取简短的User-Agent显示文本。
String getShortUserAgent(String userAgent) {
  // Wget/1.21.3 -> Wget
  if (userAgent.startsWith('Wget/')) {
    return 'Wget';
  }
  // Mozilla/5.0 (Windows...) -> Windows
  if (userAgent.contains('Windows')) {
    return 'Windows';
  }
  // Mozilla/5.0 (Macintosh...) -> Mac
  if (userAgent.contains('Macintosh')) {
    return 'Mac';
  }
  // Mozilla/5.0 (Linux; Android...) -> Android
  if (userAgent.contains('Android')) {
    return 'Android';
  }
  // Mozilla/5.0 (iPhone...) -> iOS
  if (userAgent.contains('iPhone') || userAgent.contains('iPad')) {
    return 'iOS';
  }
  // VLC/3.0.20 -> VLC
  if (userAgent.startsWith('VLC/')) {
    return 'VLC';
  }
  // Lavf/60.3.100 -> FFmpeg
  if (userAgent.startsWith('Lavf/')) {
    return 'FFmpeg';
  }
  // Chrome
  if (userAgent.contains('Chrome') && !userAgent.contains('Edg')) {
    return 'Chrome';
  }
  // Edge
  if (userAgent.contains('Edg')) {
    return 'Edge';
  }
  // Firefox
  if (userAgent.contains('Firefox')) {
    return 'Firefox';
  }
  // Safari (not Chrome)
  if (userAgent.contains('Safari') && !userAgent.contains('Chrome')) {
    return 'Safari';
  }
  // 默认显示前20个字符
  return userAgent.length > 20
      ? '${userAgent.substring(0, 20)}...'
      : userAgent;
}