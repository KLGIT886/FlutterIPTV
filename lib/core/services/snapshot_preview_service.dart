import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'service_locator.dart';

/// 频道快照预览服务
///
/// 通过 rtp2httpd 的 `X-Request-Snapshot: 1` 请求实时画面 JPEG，
/// 用于频道列表悬停/聚焦时展示实时预览（临时覆盖静态台标）。
///
/// 设计要点（参考 SrcBox 的 ThumbnailPreviewService）：
/// - 仅对 http/https 流请求快照（udp:// 组播、rtsp:// 等无法请求）；
/// - 校验 Content-Type 与 JPEG 魔数，服务器不支持时立即断开并负缓存；
/// - 短 TTL 的 LRU 缓存，连续悬停秒显，直播画面实时变化故需过期重取；
/// - 并发限流，避免批量悬停打爆 rtp2httpd 的 ffmpeg 与网络。
class SnapshotPreviewService {
  SnapshotPreviewService() {
    _client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 1500);
  }

  late final HttpClient _client;

  // 直播画面实时变化，缓存短 TTL；FCC 下约 0.3s、无 FCC 最长约 1s 返回
  static const Duration _cacheTtl = Duration(seconds: 5);
  static const int _maxCacheEntries = 200;
  final LinkedHashMap<String, _SnapshotEntry> _cache = LinkedHashMap();

  // 负缓存：服务端未开 video-snapshot 时会返回无限直播流（非 JPEG），
  // 短期内记录该 URL，避免每次悬停都重建一条无谓连接。
  static const Duration _negativeCacheTtl = Duration(seconds: 30);
  final Map<String, DateTime> _negativeCache = {};

  // 并发信号量：限制同时进行的快照请求数
  static const int _maxConcurrent = 3;
  int _active = 0;
  final List<Completer<void>> _waiters = [];

  /// 获取频道快照；失败/不支持返回 null（调用方回退台标）
  Future<Uint8List?> fetchSnapshot(String url) async {
    final trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return null;
    }

    // 命中负缓存（服务端未开快照）直接返回，避免每次悬停都建连
    final negUntil = _negativeCache[trimmed];
    if (negUntil != null) {
      if (negUntil.isAfter(DateTime.now())) return null;
      _negativeCache.remove(trimmed);
    }

    final cached = _getCached(trimmed);
    if (cached != null) return cached;

    await _acquire();
    try {
      // 双重检查：等待并发槽位期间可能已被其他请求缓存
      final recheck = _getCached(trimmed);
      if (recheck != null) return recheck;

      final result = await _request(trimmed);
      if (result.unsupported) {
        // 服务端明确返回非 JPEG（多为无限直播流），记负缓存避免重试
        _negativeCache[trimmed] = DateTime.now().add(_negativeCacheTtl);
        return null;
      }
      if (result.bytes != null) {
        _putCache(trimmed, result.bytes!);
      }
      return result.bytes;
    } finally {
      _release();
    }
  }

  Future<_SnapshotResult> _request(String url) async {
    try {
      final request = await _client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(milliseconds: 2000));
      request.headers.set('X-Request-Snapshot', '1');
      request.headers.set(HttpHeaders.acceptHeader, 'image/jpeg');
      request.headers.set(
        HttpHeaders.userAgentHeader,
        ServiceLocator.settings?.userAgent ?? 'Wget/1.21.3',
      );
      request.headers.set(HttpHeaders.connectionHeader, 'close');

      final response = await request
          .close()
          .timeout(const Duration(milliseconds: 2000));

      // 服务器不支持快照时会原样返回视频流，Content-Type 非 image/jpeg。
      // 直播流是无限的，绝不能用 drain() 读完——直接断开底层 socket。
      final mime = response.headers.contentType?.mimeType ?? '';
      if (mime.isNotEmpty && mime != 'image/jpeg') {
        response.detachSocket().then((s) {
          s.destroy();
        }).catchError((_) {});
        return _SnapshotResult.unsupported();
      }

      // 只读取有限字节即判断，且读阶段同样受超时约束，
      // 防止快照超时却仍被动读取无限流。
      final builder = BytesBuilder(copy: false);
      await for (final chunk
          in response.timeout(const Duration(milliseconds: 2000))) {
        builder.add(chunk);
        if (builder.length > 512 * 1024) break; // 快照不应超过 512KB
      }
      final bytes = builder.takeBytes();
      return _SnapshotResult(_isJpeg(bytes) ? bytes : null);
    } catch (_) {
      // 网络错误/超时等临时失败，允许下次重试
      return _SnapshotResult(null);
    }
  }

  static bool _isJpeg(Uint8List bytes) =>
      bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;

  Uint8List? _getCached(String url) {
    final entry = _cache[url];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.fetchedAt) > _cacheTtl) {
      _cache.remove(url);
      return null;
    }
    // 命中后移到队尾，实现 LRU
    _cache.remove(url);
    _cache[url] = entry;
    return entry.bytes;
  }

  void _putCache(String url, Uint8List bytes) {
    _cache.remove(url); // 重新插入到队尾
    _cache[url] = _SnapshotEntry(bytes, DateTime.now());
    while (_cache.length > _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  Future<void> _acquire() {
    if (_active < _maxConcurrent) {
      _active++;
      return Future.value();
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete(); // 唤醒一个等待者，占用释放出的槽位
    } else {
      _active--;
    }
  }

  void dispose() {
    _cache.clear();
    _negativeCache.clear();
    _client.close(force: true);
  }
}

/// 快照请求结果：bytes 为快照；unsupported 表示服务端明确不支持快照
class _SnapshotResult {
  final Uint8List? bytes;
  final bool unsupported;

  _SnapshotResult(this.bytes) : unsupported = false;

  _SnapshotResult.unsupported()
      : bytes = null,
        unsupported = true;
}

class _SnapshotEntry {
  final Uint8List bytes;
  final DateTime fetchedAt;
  _SnapshotEntry(this.bytes, this.fetchedAt);
}