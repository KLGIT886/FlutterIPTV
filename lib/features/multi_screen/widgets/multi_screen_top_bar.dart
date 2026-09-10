import 'package:material_ui/material_ui.dart';

import '../../../core/platform/platform_detector.dart';
import '../../../core/platform/windows_pip_channel.dart';
import '../../../core/i18n/app_strings.dart';

/// 分屏页顶部控制栏：返回、PiP、窗口全屏（仅 Windows）、退出分屏。
class MultiScreenTopBar extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onExitMultiScreen;
  final bool isWindowFullscreen;
  final VoidCallback onToggleFullscreen;

  const MultiScreenTopBar({
    super.key,
    this.onBack,
    this.onExitMultiScreen,
    required this.isWindowFullscreen,
    required this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // 调整顶部间距为 30，使按钮向上移动，减少与右上角信息窗口的距离并齐平
      padding: const EdgeInsets.fromLTRB(16, 30, 16, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBack ?? () => Navigator.of(context).pop(),
              tooltip: AppStrings.of(context)?.backToPlayer ?? 'Back',
            ),
            const Spacer(),
            IconButton(
              icon:
                  const Icon(Icons.picture_in_picture_alt, color: Colors.white),
              onPressed: () async {
                await WindowsPipChannel.enterPipMode();
              },
              tooltip: AppStrings.of(context)?.miniMode ?? 'Mini Mode',
            ),
            if (PlatformDetector.isWindows)
              IconButton(
                icon: Icon(
                  isWindowFullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  color: Colors.white,
                ),
                onPressed: onToggleFullscreen,
                tooltip: isWindowFullscreen ? '退出全屏' : '全屏',
              ),
            IconButton(
              icon: const Icon(Icons.grid_off_rounded, color: Colors.white),
              onPressed: onExitMultiScreen,
              tooltip: AppStrings.of(context)?.exitMultiScreen ?? '退出分屏',
            ),
          ],
        ),
      ),
    );
  }
}
