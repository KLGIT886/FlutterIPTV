import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/platform/windows_pip_channel.dart';

class PlayerMiniControls extends StatelessWidget {
  final FocusNode playerFocusNode;
  final Function(bool) onFullScreenChanged;

  const PlayerMiniControls({
    super.key,
    required this.playerFocusNode,
    required this.onFullScreenChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 整个区域可拖拽
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.5),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Column(
          children: [
            // 顶部：只保留恢复和关闭按钮，不显示标题
            Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 恢复大小按钮
                  GestureDetector(
                    onTap: () async {
                      await WindowsPipChannel.exitPipMode();
                      // 延迟同步全屏状态，等待窗口恢复完成
                      if (PlatformDetector.isWindows) {
                        await Future.delayed(const Duration(milliseconds: 300));
                        final isFullScreen = await windowManager.isFullScreen();
                        onFullScreenChanged(isFullScreen);
                      }
                      // 恢复焦点到播放器
                      playerFocusNode.requestFocus();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.fullscreen,
                          color: Colors.white, size: 14),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // 关闭按钮
                  GestureDetector(
                    onTap: () {
                      WindowsPipChannel.exitPipMode();
                      context.read<PlayerProvider>().stop();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // 底部：静音 + 播放/暂停按钮
            Padding(
              padding: const EdgeInsets.all(8),
              child: Consumer<PlayerProvider>(
                builder: (context, provider, _) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 静音按钮
                      GestureDetector(
                        onTap: provider.toggleMute,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            provider.isMuted
                                ? Icons.volume_off
                                : Icons.volume_up,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 播放/暂停按钮
                      GestureDetector(
                        onTap: provider.togglePlayPause,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            gradient: AppTheme.lotusGradient,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            provider.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
