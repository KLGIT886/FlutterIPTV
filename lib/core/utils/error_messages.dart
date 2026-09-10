import 'package:flutter/widgets.dart';

import '../i18n/app_strings.dart';

/// 将播放列表导入 / 刷新时抛出的错误键（如解析器抛出的
/// 'errorTimeout' / 'errorNetwork'，或直接包含 404/403 的描述）映射为用户友好文案。
///
/// 解析器（`m3u_parser` / `txt_parser`）在超时 / 网络错误时抛出
/// `Exception('errorTimeout')` 等键，但 UI 原样展示会暴露内部键串（P2-3）。
/// 此处统一映射为可读提示；[context] 为 null 时回退到英文默认文案。
String friendlyPlaylistError(String? raw, BuildContext? context) {
  if (raw == null) return '未知错误';
  // raw 形如 "Failed to refresh playlist: Exception: errorTimeout"
  final cleaned = raw.replaceAll('Exception: ', '').trim();
  final strings = context != null ? AppStrings.of(context) : null;

  if (cleaned.contains('errorTimeout')) {
    return strings?.errorTimeout ?? '连接超时，请检查网络或链接';
  }
  if (cleaned.contains('errorNetwork')) {
    return strings?.errorNetwork ?? '网络连接失败，请检查网络';
  }
  if (cleaned.contains('404')) {
    return strings != null ? '播放列表未找到 (404)' : 'Playlist not found (404)';
  }
  if (cleaned.contains('403')) {
    return strings != null ? '访问被拒绝 (403)' : 'Access denied (403)';
  }
  return cleaned;
}
