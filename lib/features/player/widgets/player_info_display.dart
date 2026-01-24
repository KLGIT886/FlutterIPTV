import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/platform/windows_pip_channel.dart';

class PlayerInfoDisplay extends StatelessWidget {
  final bool isMultiScreenMode;

  const PlayerInfoDisplay({
    super.key,
    required this.isMultiScreenMode,
  });

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond >= 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else if (bytesPerSecond >= 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
    } else {
      return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final player = context.watch<PlayerProvider>();

    // 1. Mini mode FPS display (bottom right)
    if (WindowsPipChannel.isInPipMode) {
      if (!settings.showFps || player.state != PlayerState.playing) {
        return const SizedBox.shrink();
      }
      final fps = player.currentFps;
      if (fps <= 0) return const SizedBox.shrink();

      return Positioned(
        bottom: 4,
        right: 4,
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.8),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              '${fps.toStringAsFixed(0)} FPS',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    // 2. Normal mode info display (top right)
    // 分屏模式、迷你模式或非播放状态不显示
    if (isMultiScreenMode || player.state != PlayerState.playing) {
      return const SizedBox.shrink();
    }

    // 检查是否有任何信息需要显示
    final showAny = settings.showNetworkSpeed ||
        settings.showClock ||
        settings.showFps ||
        settings.showVideoInfo;
    if (!showAny) return const SizedBox.shrink();

    final fps = player.currentFps;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      right: 16,
      child: IgnorePointer(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 网速显示 - 绿色 (仅 TV 端显示，Windows 端不显示)
            if (settings.showNetworkSpeed &&
                player.downloadSpeed > 0 &&
                PlatformDetector.isTV)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatSpeed(player.downloadSpeed),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            // 时间显示 - 黑色
            if (settings.showClock)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: StreamBuilder(
                  stream: Stream.periodic(const Duration(seconds: 1)),
                  builder: (context, snapshot) {
                    final now = DateTime.now();
                    return Text(
                      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
            // FPS 显示 - 红色
            if (settings.showFps && fps > 0)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${fps.toStringAsFixed(0)} FPS',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            // 分辨率显示 - 蓝色
            if (settings.showVideoInfo &&
                player.videoWidth > 0 &&
                player.videoHeight > 0)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${player.videoWidth}x${player.videoHeight}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
