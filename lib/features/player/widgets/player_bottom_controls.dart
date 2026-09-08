import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../epg/providers/epg_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/player_provider.dart';
import 'player_formatters.dart';
import 'volume_control_bar.dart';

/// 播放界面底栏：EPG 当前/下一节目、进度条、控件按钮行与键盘提示。
///
/// 交互回调交由父层处理：[onToggleEpg]、[onShowSourceIndicator]、
/// [onShowSettings]、[onToggleCategory]、[onToggleFullScreen]；全屏态通过
/// [isFullScreen] 传入以切换图标。
class PlayerBottomControls extends StatelessWidget {
  /// 当前是否全屏（用于全屏按钮图标）。
  final bool isFullScreen;

  /// 开关 EPG 面板（父层联动隐藏控制层）。
  final VoidCallback onToggleEpg;

  /// 源切换后显示切换指示。
  final void Function(PlayerProvider provider) onShowSourceIndicator;

  /// 打开设置面板。
  final void Function(BuildContext context) onShowSettings;

  /// 开关分类面板并定位当前频道。
  final VoidCallback onToggleCategory;

  /// 切换全屏并恢复播放器焦点。
  final VoidCallback onToggleFullScreen;

  const PlayerBottomControls({
    super.key,
    required this.isFullScreen,
    required this.onToggleEpg,
    required this.onShowSourceIndicator,
    required this.onShowSettings,
    required this.onToggleCategory,
    required this.onToggleFullScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildEpgInfo(context, provider),
              _buildProgressBar(context, provider),
              _buildControlButtons(context, provider),
              _buildKeyboardHints(context),
            ],
          ),
        );
      },
    );
  }

  /// EPG 当前节目与下一节目信息条。
  Widget _buildEpgInfo(BuildContext context, PlayerProvider provider) {
    return Consumer<EpgProvider>(
      builder: (context, epgProvider, _) {
        final channel = provider.currentChannel;
        final currentProgram = epgProvider.getCurrentProgram(
            channel?.epgId, channel?.name);
        final nextProgram =
            epgProvider.getNextProgram(channel?.epgId, channel?.name);

        if (currentProgram != null || nextProgram != null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x33000000),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentProgram != null)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.getPrimaryColor(context),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                              AppStrings.of(context)?.nowPlaying ??
                                  'Now playing',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            currentProgram.title,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          (AppStrings.of(context)?.endsInMinutes ??
                                  'Ends in {minutes} min')
                              .replaceFirst('{minutes}',
                                  '${currentProgram.remainingMinutes}'),
                          style: const TextStyle(
                              color: Color(0x99FFFFFF), fontSize: 11),
                        ),
                      ],
                    ),
                  if (nextProgram != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.getPrimaryColor(context)
                                    .withOpacity(0.7),
                                AppTheme.getSecondaryColor(context)
                                    .withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                              AppStrings.of(context)?.upNext ?? 'Up next',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            nextProgram.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  /// 进度条与时间显示（仅可 seek 内容）。
  Widget _buildProgressBar(BuildContext context, PlayerProvider provider) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        if (!provider
            .shouldShowProgressBar(settings.progressBarMode)) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              // 进度条（更小的高度）
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2, // 减小轨道高度
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 5),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 10),
                  activeTrackColor: AppTheme.getPrimaryColor(context),
                  inactiveTrackColor: const Color(0x33FFFFFF),
                  thumbColor: Colors.white,
                  overlayColor:
                      AppTheme.getPrimaryColor(context).withOpacity(0.3),
                ),
                child: Slider(
                  value: provider.position.inSeconds.toDouble().clamp(
                      0, provider.duration.inSeconds.toDouble()),
                  max: provider.duration.inSeconds
                      .toDouble()
                      .clamp(1, double.infinity),
                  onChanged: (value) {
                    provider.seek(Duration(seconds: value.toInt()));
                  },
                ),
              ),
              // 时间显示（更宽的字体和间距）
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatDuration(provider.position),
                      style: const TextStyle(
                          color: Color(0x99FFFFFF), fontSize: 10),
                    ),
                    Text(
                      formatDuration(provider.duration),
                      style: const TextStyle(
                          color: Color(0x99FFFFFF), fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 控件按钮行（音量、EPG、源切换、播放/暂停、设置、分类、全屏）。
  Widget _buildControlButtons(BuildContext context, PlayerProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Volume control
          VolumeControlBar(provider: provider),

          const SizedBox(width: 16),

          // EPG Button
          if (provider.currentChannel?.epgId != null ||
              provider.currentChannel?.hasCatchup == true)
            TVFocusable(
              onSelect: onToggleEpg,
              focusScale: 1.0,
              showFocusBorder: false,
              child: Row(
                children: [
                  const Icon(
                    Icons.list_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppStrings.of(context)?.epg ?? 'EPG',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              builder: (context, isFocused, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isFocused
                        ? AppTheme.getPrimaryColor(context)
                        : const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isFocused
                          ? AppTheme.getPrimaryColor(context)
                          : const Color(0x1AFFFFFF),
                      width: isFocused ? 2 : 1,
                    ),
                  ),
                  child: child,
                );
              },
            ),

          if (provider.currentChannel?.epgId != null ||
              provider.currentChannel?.hasCatchup == true)
            const SizedBox(width: 16),

          // 手机端源切换按钮 - 上一个源
          if (PlatformDetector.isMobile &&
              provider.currentChannel != null &&
              provider.currentChannel!.hasMultipleSources)
            TVFocusable(
              onSelect: () {
                provider.switchToPreviousSource();
                onShowSourceIndicator(provider);
              },
              focusScale: 1.0,
              showFocusBorder: false,
              builder: (context, isFocused, child) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isFocused
                        ? AppTheme.getPrimaryColor(context)
                        : const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isFocused
                          ? AppTheme.getPrimaryColor(context)
                          : const Color(0x1AFFFFFF),
                      width: isFocused ? 2 : 1,
                    ),
                  ),
                  child: child,
                );
              },
              child: const Icon(Icons.skip_previous_rounded,
                  color: Colors.white, size: 18),
            ),

          if (PlatformDetector.isMobile &&
              provider.currentChannel != null &&
              provider.currentChannel!.hasMultipleSources)
            const SizedBox(width: 8),

          // Play/Pause - Lotus gradient button (smaller)
          TVFocusable(
            autofocus: true,
            onSelect: provider.togglePlayPause,
            focusScale: 1.0,
            showFocusBorder: false,
            builder: (context, isFocused, child) {
              return Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppTheme.getGradient(context),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        isFocused ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.getPrimaryColor(context)
                          .withAlpha(isFocused ? 100 : 50),
                      blurRadius: isFocused ? 16 : 8,
                      spreadRadius: isFocused ? 2 : 1,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: Icon(
              provider.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),

          // 手机端源切换按钮 - 下一个源
          if (PlatformDetector.isMobile &&
              provider.currentChannel != null &&
              provider.currentChannel!.hasMultipleSources)
            const SizedBox(width: 8),

          if (PlatformDetector.isMobile &&
              provider.currentChannel != null &&
              provider.currentChannel!.hasMultipleSources)
            TVFocusable(
              onSelect: () {
                provider.switchToNextSource();
                onShowSourceIndicator(provider);
              },
              focusScale: 1.0,
              showFocusBorder: false,
              builder: (context, isFocused, child) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isFocused
                        ? AppTheme.getPrimaryColor(context)
                        : const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isFocused
                          ? AppTheme.getPrimaryColor(context)
                          : const Color(0x1AFFFFFF),
                      width: isFocused ? 2 : 1,
                    ),
                  ),
                  child: child,
                );
              },
              child: const Icon(Icons.skip_next_rounded,
                  color: Colors.white, size: 18),
            ),

          if (!PlatformDetector.isMobile &&
              provider.currentChannel != null &&
              provider.currentChannel!.hasMultipleSources) ...[
            const SizedBox(width: 8),
            TVFocusable(
              onSelect: () {
                provider.switchToNextSource();
                onShowSourceIndicator(provider);
              },
              focusScale: 1.0,
              showFocusBorder: false,
              builder: (context, isFocused, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isFocused
                        ? AppTheme.getPrimaryColor(context)
                        : const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isFocused
                          ? AppTheme.getPrimaryColor(context)
                          : const Color(0x1AFFFFFF),
                      width: isFocused ? 2 : 1,
                    ),
                  ),
                  child: child,
                );
              },
              child: Text(
                '${AppStrings.of(context)?.source ?? 'Source'} ${provider.currentSourceIndex}/${provider.sourceCount}',
                style:
                    const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],

          const SizedBox(width: 16),

          // Settings button (smaller)
          TVFocusable(
            onSelect: () => onShowSettings(context),
            focusScale: 1.0,
            showFocusBorder: false,
            builder: (context, isFocused, child) {
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isFocused
                      ? AppTheme.getPrimaryColor(context)
                      : const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isFocused
                        ? AppTheme.getPrimaryColor(context)
                        : const Color(0x1AFFFFFF),
                    width: isFocused ? 2 : 1,
                  ),
                ),
                child: child,
              );
            },
            child: const Icon(Icons.settings_rounded,
                color: Colors.white, size: 18),
          ),

          const SizedBox(width: 16),

          // Category menu button
          TVFocusable(
            onSelect: onToggleCategory,
            focusScale: 1.0,
            showFocusBorder: false,
            builder: (context, isFocused, child) {
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isFocused
                      ? AppTheme.getPrimaryColor(context)
                      : const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isFocused
                        ? AppTheme.getPrimaryColor(context)
                        : const Color(0x1AFFFFFF),
                    width: isFocused ? 2 : 1,
                  ),
                ),
                child: child,
              );
            },
            child: const Icon(Icons.menu_rounded,
                color: Colors.white, size: 18),
          ),

          // Windows 全屏按钮
          if (PlatformDetector.isWindows) ...[
            const SizedBox(width: 16),
            TVFocusable(
              onSelect: onToggleFullScreen,
              focusScale: 1.0,
              showFocusBorder: false,
              builder: (context, isFocused, child) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isFocused
                        ? AppTheme.getPrimaryColor(context)
                        : const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isFocused
                          ? AppTheme.getPrimaryColor(context)
                          : const Color(0x1AFFFFFF),
                      width: isFocused ? 2 : 1,
                    ),
                  ),
                  child: child,
                );
              },
              child: Icon(
                  isFullScreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  color: Colors.white,
                  size: 18),
            ),
          ],
        ],
      ),
    );
  }

  /// 键盘操作提示（仅 DPad 导航启用时显示）。
  Widget _buildKeyboardHints(BuildContext context) {
    if (!PlatformDetector.useDPadNavigation) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        AppStrings.of(context)?.playerHintTV ??
            '☰️ 切换频道 · 🎛️ 切换源· 长按🔄 分类 · OK 播放/暂停 · 长按OK 收藏',
        style:
            const TextStyle(color: Color(0x66FFFFFF), fontSize: 11),
      ),
    );
  }
}