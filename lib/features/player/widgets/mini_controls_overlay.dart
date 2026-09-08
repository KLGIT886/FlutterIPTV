import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/player_provider.dart';

/// 画中画/迷你窗口模式下的简化控制栏。
class MiniControlsOverlay extends StatelessWidget {
  final VoidCallback onRestore;
  final VoidCallback onClose;

  const MiniControlsOverlay({
    super.key,
    required this.onRestore,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 整个区域可拖动
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
            // 顶部：只保留恢复和关闭，不显示标题文字和退出按钮
            Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 恢复大小按钮
                  GestureDetector(
                    onTap: onRestore,
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
                    onTap: onClose,
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
