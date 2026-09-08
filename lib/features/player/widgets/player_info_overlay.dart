import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/platform/platform_detector.dart';
import '../../../core/platform/windows_pip_channel.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/player_provider.dart';
import 'player_formatters.dart';

/// 播放界面右上角信息显示条：网速、时钟、FPS、分辨率、User-Agent。
///
/// 各显示项的开头由 [SettingsProvider] 开关控制；分屏模式由 [isMultiScreen]
/// 决定是否显示。PIP 模式下自动隐藏（改为底部 FPS 徽标）。
class PlayerInfoOverlay extends StatelessWidget {
  /// 是否处于分屏模式（分屏时每个分屏自带信息，不显示全局条）。
  final bool isMultiScreen;

  const PlayerInfoOverlay({super.key, required this.isMultiScreen});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final player = context.watch<PlayerProvider>();

    // 分屏模式、迷你模式或非播放状态不显示
    if (isMultiScreen ||
        WindowsPipChannel.isInPipMode ||
        player.state != PlayerState.playing) {
      return const SizedBox.shrink();
    }

    // 检查是否有任何信息需要显示
    final showAny = settings.showNetworkSpeed ||
        settings.showClock ||
        settings.showFps ||
        settings.showVideoInfo ||
        settings.showUserAgent;
    if (!showAny) return const SizedBox.shrink();

    final fps = player.currentFps;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      right: 16,
      child: IgnorePointer(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 网速显示（仅TV端显示，Windows端不显示）
            if (settings.showNetworkSpeed &&
                player.downloadSpeed > 0 &&
                PlatformDetector.isTV)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  formatSpeed(player.downloadSpeed),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: StreamBuilder(
                  stream:
                      Stream.periodic(const Duration(seconds: 1)),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            // User-Agent 显示 - 紫色
            if (settings.showUserAgent)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'UA: ${getShortUserAgent(settings.userAgent)}',
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