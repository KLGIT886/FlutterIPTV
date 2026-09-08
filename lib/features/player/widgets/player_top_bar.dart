import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../providers/player_provider.dart';

/// 播放界面顶栏：返回按钮 + 频道信息（LIVE/源/解析信息）+ 收藏 + 画中画 + 多屏按钮。
///
/// 交互逻辑：返回、收藏由组件内完成；画中画/多屏按钮由父层构建后以 [pipButton]、
/// [multiScreenButton] 注入。返回行为通过 [onBack] 回调交给父层处理（清理错误、
/// 退出全屏、返回导航）。
class PlayerTopBar extends StatelessWidget {
  /// 当前频道为空时回退显示的频道名。
  final String fallbackChannelName;

  /// 返回按钮逻辑（父层：清理错误提示、退出全屏并返回上一页）。
  final Future<void> Function() onBack;

  /// 画中画按钮，父层在支持平台构建并传入。
  final Widget? pipButton;

  /// 多屏切换按钮，父层在桌面平台构建并传入。
  final Widget? multiScreenButton;

  const PlayerTopBar({
    super.key,
    required this.fallbackChannelName,
    required this.onBack,
    this.pipButton,
    this.multiScreenButton,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 调整顶部间距为 30，使按钮向上移动，减少与信息窗口的距离，同时保持不重叠
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 16),
      child: Row(
        children: [
          _buildBackButton(context),
          const SizedBox(width: 16),
          Expanded(child: _buildChannelInfo(context)),
          _buildFavoriteButton(context),
          if (pipButton != null) ...[
            const SizedBox(width: 8),
            pipButton!,
          ],
          if (multiScreenButton != null) ...[
            const SizedBox(width: 8),
            multiScreenButton!,
          ],
        ],
      ),
    );
  }

  /// 返回按钮。
  Widget _buildBackButton(BuildContext context) {
    return TVFocusable(
      onSelect: onBack,
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
      child: const Icon(Icons.arrow_back_rounded,
          color: Colors.white, size: 18),
    );
  }

  /// 频道信息区（频道名 + LIVE/源/解析信息）。
  Widget _buildChannelInfo(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              provider.currentChannel?.name ?? fallbackChannelName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                // Live indicator
                if (provider.state == PlayerState.playing) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: AppTheme.getGradient(context),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle,
                            color: Colors.white, size: 6),
                        SizedBox(width: 4),
                        Text('LIVE',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Source indicator (if multiple sources)
                if (provider.currentChannel != null &&
                    provider.currentChannel!.hasMultipleSources) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.getPrimaryColor(context)
                          .withOpacity(0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.swap_horiz,
                            color: Colors.white, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          '${AppStrings.of(context)?.source ?? 'Source'} ${provider.currentSourceIndex}/${provider.sourceCount}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Video info
                if (provider.videoInfo.isNotEmpty)
                  Flexible(
                    child: Text(
                      provider.videoInfo,
                      style: const TextStyle(
                          color: Color(0x99FFFFFF), fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// 收藏按钮。
  Widget _buildFavoriteButton(BuildContext context) {
    return Consumer<FavoritesProvider>(
      builder: (context, favorites, _) {
        final playerProvider = context.read<PlayerProvider>();
        final currentChannel = playerProvider.currentChannel;
        final isFav = currentChannel != null &&
            favorites.isFavorite(currentChannel.id ?? 0);

        return TVFocusable(
          onSelect: () async {
            if (currentChannel != null) {
              ServiceLocator.log.d(
                  'TV播放器: 尝试切换收藏状态 - 频道: ${currentChannel.name}, ID: ${currentChannel.id}');
              final success =
                  await favorites.toggleFavorite(currentChannel);
              ServiceLocator.log.d(
                  'TV播放器: 收藏切换${success ? "成功" : "失败"}');

              if (success) {
                final newIsFav =
                    favorites.isFavorite(currentChannel.id ?? 0);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      newIsFav ? '已添加到收藏' : '已从收藏中移除',
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            } else {
              ServiceLocator.log.d('TV播放器: 当前频道为空，无法切换收藏');
            }
          },
          focusScale: 1.0,
          showFocusBorder: false,
          builder: (context, isFocused, child) {
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: isFav ? AppTheme.getGradient(context) : null,
                color: isFav
                    ? null
                    : (isFocused
                        ? AppTheme.getPrimaryColor(context)
                        : const Color(0x33FFFFFF)),
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
            isFav ? Icons.favorite : Icons.favorite_border_rounded,
            color: Colors.white,
            size: 18,
          ),
        );
      },
    );
  }
}