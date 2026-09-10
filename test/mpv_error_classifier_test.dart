import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_iptv/core/utils/mpv_error_classifier.dart';

/// 验证「码流瞬时错误」的识别。
///
/// 这类错误常让硬解初始化失败并报出含 decoder/hwdec 字样的信息；
/// 若被软件回退逻辑误判，一次起播丢包就会把播放器永久降级到软解。
void main() {
  group('识别为瞬时错误（不应触发软解回退）', () {
    test('PPS / SPS 越界', () {
      expect(isTransientStreamError('hevc: PPS id out of range: 0'), isTrue);
      expect(isTransientStreamError('h264: SPS id out of range: 3'), isTrue);
    });

    test('无效 / 无法解码的 NALU', () {
      expect(isTransientStreamError('hevc: Skipping invalid undecodable NALU: 1'), isTrue);
    });

    test('帧/数据不完整', () {
      expect(isTransientStreamError('ffmpeg: missing picture in access unit'), isTrue);
      expect(isTransientStreamError('Corrupt decoded frame'), isTrue);
      expect(isTransientStreamError('Packet truncated'), isTrue);
      expect(isTransientStreamError('Invalid data found when processing input'), isTrue);
    });
  });

  group('不识别为瞬时错误（可触发软解回退）', () {
    test('解码器 / 硬解能力类错误', () {
      expect(isTransientStreamError('Video decoder init failed'), isFalse);
      expect(isTransientStreamError('hwdec init failed: d3d11va'), isFalse);
      expect(isTransientStreamError('Codec not found: hevc'), isFalse);
      expect(isTransientStreamError('mediacodec: failed to configure'), isFalse);
    });

    test('常规错误与空串', () {
      expect(isTransientStreamError(''), isFalse);
      expect(isTransientStreamError('network timeout'), isFalse);
    });
  });

  test('大小写不敏感', () {
    expect(isTransientStreamError('HEVC: PPS ID OUT OF RANGE: 0'), isTrue);
    expect(isTransientStreamError('Skipping Invalid Undecodable NALU'), isTrue);
  });
}
