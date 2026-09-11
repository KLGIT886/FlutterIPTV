import 'dart:async';

import 'package:media_kit/media_kit.dart';

import '../services/service_locator.dart';

/// mpv 低层调优的统一实现（单屏与分屏播放器共用）。
///
/// 此前 `player_provider` 与 `multi_screen_provider` 各自维护一份近乎逐行重复的
/// mpv 属性读写 / 缓冲配置 / 滤镜链验证 / hwdec 选择逻辑，容易行为漂移。
/// 此处收敛为单一实现，两个 provider 仅保留一行委托，调用点零改动。
class MpvTuner {
  final Player? player;
  final String logTag;

  MpvTuner(this.player, {this.logTag = 'MpvTuner'});

  /// 安全调用 setProperty，单个失败不影响其他调用。成功返回 true。
  Future<bool> safeSetProperty(String property, String value, String label) async {
    try {
      final nativePlayer = player?.platform as dynamic;
      await nativePlayer.setProperty(property, value);
      return true;
    } catch (e) {
      ServiceLocator.log.d('设置 $label 失败: $e', tag: logTag);
      return false;
    }
  }

  /// 安全读取 getProperty，失败返回 null。
  Future<String?> safeGetProperty(String property, String label) async {
    try {
      final nativePlayer = player?.platform as dynamic;
      return await nativePlayer.getProperty(property);
    } catch (e) {
      ServiceLocator.log.d('读取 $label 失败: $e', tag: logTag);
      return null;
    }
  }

  /// 判断源是否为 FCC（Fast Channel Change）流。
  /// 通过 URL 是否包含 fcc 关键字判断（忽略大小写及 $ 标签后缀）。
  static bool isFccSource(String url) {
    final clean = url.split('\$').first.trim();
    return clean.toLowerCase().contains('fcc');
  }

  /// 返回用户配置的 hwdec 模式（考虑软解码设置）。
  static String configuredHwdecMode({
    required bool software,
    required String windowsHwdecMode,
  }) {
    if (software) return 'no';
    switch (windowsHwdecMode) {
      case 'auto-copy':
        return 'auto-copy';
      case 'd3d11va':
        return 'd3d11va';
      case 'dxva2':
        return 'dxva2';
      case 'auto-safe':
      default:
        return 'auto-safe';
    }
  }

  /// 根据源是否 FCC 配置 mpv 缓冲参数（须在 open() 之前调用）。
  ///
  /// FCC 流用于快速切台，缓存会引入额外延迟，因此禁用缓存（`cache=no`）并禁用
  /// 向后回读（`demuxer-max-back-bytes=0`）；普通流则恢复 media_kit 默认的启用
  /// 缓存，demuxer 上限用 [bufferSize]。
  ///
  /// 关于 FCC 的 `demuxer-max-bytes`：取 **64MB**（不是更小值）。原因是高码率
  /// 组播流（如 CCTV 8K ≈ 100Mbps）在 10MB 级上限下 demuxer 队列不足，会出现
  /// 读取跟不上、花屏/卡顿；64MB 可保证 8K/100Mbps 正常播放。代价是每路最多多占
  /// 64MB（分屏 4 路合计约 256MB），属有意取舍——请勿按"FCC 应尽量小"改回。
  ///
  /// [includeLavfOpts] 为 true 时额外重写 demuxer-lavf-o（单屏路径使用）；
  /// 分屏路径保持原行为不设置该项。
  Future<void> applyBufferConfig(
    String realUrl,
    int bufferSize, {
    required bool includeLavfOpts,
  }) async {
    final isFcc = isFccSource(realUrl);
    if (includeLavfOpts) {
      // 不做自定义 probesize：收敛 ffmpeg 探测上限会破坏 4K/25Mbps 组播流——
      // 128KB 级小值读不到首个关键帧（HEVC 的 VPS/SPS/PPS 只出现在 IDR），
      // 导致 avformat_find_stream_info 提前结束但"未选择任何流"，起播永久转圈。
      final lavfOpts = [
        'seg_max_retry=5',
        'strict=experimental',
        'allowed_extensions=ALL',
        'protocol_whitelist=[udp,rtp,rtsp,tcp,tls,data,file,http,https,crypto]',
      ].join(',');
      ServiceLocator.log.d(
          '缓冲配置: ${isFcc ? "FCC(禁用缓存)" : "普通流"}, '
          'cache=${isFcc ? "no" : "yes"}, '
          'demuxer-max-bytes=${isFcc ? "67108864" : bufferSize}, '
          'demuxer-max-back-bytes=${isFcc ? "0" : bufferSize}, '
          'probesize=默认(约495KB)',
          tag: logTag);
      await safeSetProperty('demuxer-lavf-o', lavfOpts, 'demuxer-lavf-o');
    } else {
      ServiceLocator.log.d(
          '缓冲配置: ${isFcc ? "FCC(禁用缓存)" : "普通流"}, '
          'cache=${isFcc ? "no" : "yes"}, '
          'demuxer-max-bytes=${isFcc ? "67108864" : bufferSize}, '
          'demuxer-max-back-bytes=${isFcc ? "0" : bufferSize}',
          tag: logTag);
    }
    await safeSetProperty('cache', isFcc ? 'no' : 'yes', 'cache');
    if (isFcc) {
      // 64MB：为高码率 FCC 流（CCTV 8K ≈ 100Mbps）预留足够 demuxer 队列，
      // 10MB 级会导致读取不足、花屏/卡顿。详见方法文档。
      await safeSetProperty(
          'demuxer-max-bytes', '${64 * 1024 * 1024}', 'demuxer-max-bytes');
      await safeSetProperty(
          'demuxer-max-back-bytes', '0', 'demuxer-max-back-bytes');
    } else {
      await safeSetProperty(
          'demuxer-max-bytes', '$bufferSize', 'demuxer-max-bytes');
      await safeSetProperty(
          'demuxer-max-back-bytes', '$bufferSize', 'demuxer-max-back-bytes');
    }
  }

  /// 验证滤镜链/去交错是否真正生效（修复验证盲区）。
  ///
  /// mpv 设置 `vf`/`deinterlace` 后异步重建滤镜链，失败时可能只通过 log 流或
  /// 只通过 error 流抛出错误信号，故两者同时监听；均无失败信号则视为生效。
  Future<bool> verifyFilterChainActive(String label) async {
    final failureSignaled = Completer<bool>();

    void checkFailure(String msg) {
      if (msg.contains('Disabling filter') ||
          msg.contains('Impossible to convert') ||
          msg.contains('failed to configure the filter graph') ||
          msg.contains('no such filter') ||
          msg.contains('error creating filters') ||
          msg.contains('Error parsing option') ||
          msg.contains('option not found')) {
        if (!failureSignaled.isCompleted) failureSignaled.complete(true);
      }
    }

    final logSub = player!.stream.log.listen((log) => checkFailure(log.text));
    final errSub = player!.stream.error.listen((err) {
      if (err.isNotEmpty) checkFailure(err);
    });
    final failed = await failureSignaled.future.timeout(
      const Duration(milliseconds: 350),
      onTimeout: () => false, // 超时未出现失败信号 => 视为滤镜链生效
    );
    await logSub.cancel();
    await errSub.cancel();
    if (failed) {
      ServiceLocator.log.d('滤镜链验证失败($label): 检测到 mpv 滤镜配置错误', tag: logTag);
    }
    return !failed;
  }
}
