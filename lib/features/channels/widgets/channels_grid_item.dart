import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/navigation/app_router.dart';
import '../../../core/widgets/channel_card.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/platform/native_player_channel.dart';
import '../../../core/services/epg_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/models/channel.dart';

import '../providers/channel_provider.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../epg/providers/epg_provider.dart';
import '../../multi_screen/providers/multi_screen_provider.dart';

/// 频道网格中的单个频道卡片
class ChannelGridItem extends StatelessWidget {
  final Channel channel;
  final bool isFirstColumn;
  final bool isLastRow;
  final int crossAxisCount;
  final FocusNode? focusNode;
  final VoidCallback? onFocused;
  final VoidCallback? onLeft;
  final VoidCallback? onDown;
  final VoidCallback onTest;
  final Function(Channel) onShowOptions;

  const ChannelGridItem({
    super.key,
    required this.channel,
    required this.isFirstColumn,
    required this.isLastRow,
    required this.crossAxisCount,
    this.focusNode,
    this.onFocused,
    this.onLeft,
    this.onDown,
    required this.onTest,
    required this.onShowOptions,
  });

  @override
  Widget build(BuildContext context) {
    // 读取首页字体缩放设置（分类页与首页保持一致）
    final fontScale = context.watch<SettingsProvider>().homeFontScale;

    // ✅ 使用 select 替代 watch，只监听特定频道的数据变化
    final isFavorite = context.select<FavoritesProvider, bool>(
      (provider) => provider.isFavorite(channel.id ?? 0),
    );

    final isUnavailable =
        ChannelProvider.isUnavailableChannel(channel.groupName);

    // ✅ 使用 select 获取 EPG 数据，只在该频道的 EPG 变化时重建
    final currentProgram = context.select<EpgProvider, EpgProgram?>(
      (provider) => provider.getCurrentProgram(channel.epgId, channel.name),
    );

    final nextProgram = context.select<EpgProvider, EpgProgram?>(
      (provider) => provider.getNextProgram(channel.epgId, channel.name),
    );

    return ChannelCard(
      name: channel.name,
      logoUrl: channel.logoUrl,
      channel: channel,
      groupName: isUnavailable
          ? ChannelProvider.extractOriginalGroup(channel.groupName)
          : channel.groupName,
      currentProgram: currentProgram?.title,
      nextProgram: nextProgram?.title,
      isFavorite: isFavorite,
      isUnavailable: isUnavailable,
      fontScale: fontScale,
      autofocus: false, // 移除 autofocus，由 focusNode 控制
      focusNode: focusNode,
      onFocused: onFocused,
      onLeft: onLeft,
      onDown: onDown,
      onFavoriteToggle: () {
        context.read<FavoritesProvider>().toggleFavorite(channel);
      },
      onTest: onTest,
      onTap: () async {
        final settingsProvider = context.read<SettingsProvider>();

        // 保存上次播放的频道ID
        if (settingsProvider.rememberLastChannel && channel.id != null) {
          settingsProvider.setLastChannelId(channel.id);
        }

        ServiceLocator.log.d(
            'ChannelsScreen: onTap - enableMultiScreen=${settingsProvider.enableMultiScreen}, isDesktop=${PlatformDetector.isDesktop}, isTV=${PlatformDetector.isTV}');

        // 检查是否启用了分屏模式
        if (settingsProvider.enableMultiScreen) {
          // TV 端使用原生分屏播放器
          if (PlatformDetector.isTV && PlatformDetector.isAndroid) {
            ServiceLocator.log.d(
                'ChannelsScreen: TV Multi-screen mode, launching native multi-screen player');
            final channelProvider = context.read<ChannelProvider>();
            final favoritesProvider = context.read<FavoritesProvider>();
            // ✅ 使用全部频道而不是分页显示的频道
            final channels = channelProvider.allChannels;

            // 设置 providers 用于收藏功能
            NativePlayerChannel.setProviders(
                favoritesProvider, channelProvider, settingsProvider);

            // 找到当前点击频道的索引
            final clickedIndex =
                channels.indexWhere((c) => c.url == channel.url);

            // TV端原生分屏播放器也需要记录观看历史
            if (channel.id != null) {
              await ServiceLocator.watchHistory
                  .addWatchHistory(channel.id!, channel.playlistId);
              ServiceLocator.log.d(
                  'ChannelsScreen: Recorded watch history for channel ${channel.name} (TV multi-screen)');
            }

            // 准备频道数据
            final urls = channels.map((c) => c.url).toList();
            final names = channels.map((c) => c.name).toList();
            final groups = channels.map((c) => c.groupName ?? '').toList();
            final sources = channels.map((c) => c.sources).toList();
            final logos = channels.map((c) => c.logoUrl ?? '').toList();

            // 启动原生分屏播放器，传递初始频道索引和音量增强
            await NativePlayerChannel.launchMultiScreen(
              urls: urls,
              names: names,
              groups: groups,
              sources: sources,
              logos: logos,
              initialChannelIndex: clickedIndex >= 0 ? clickedIndex : 0,
              volumeBoostDb: settingsProvider.volumeBoost,
              defaultScreenPosition: settingsProvider.defaultScreenPosition,
              showChannelName: settingsProvider.showMultiScreenChannelName,
              userAgent: settingsProvider.userAgent,
              onClosed: () {
                ServiceLocator.log
                    .d('ChannelsScreen: Native multi-screen closed');
              },
            );
          } else if (PlatformDetector.isDesktop) {
            ServiceLocator.log.d(
                'ChannelsScreen: Desktop Multi-screen mode, playing channel: ${channel.name}');
            // 桌面端分屏模式：在指定位置播放频道
            final multiScreenProvider = context.read<MultiScreenProvider>();
            final defaultPosition = settingsProvider.defaultScreenPosition;
            // 设置音量增强到分屏Provider
            multiScreenProvider.setVolumeSettings(
                1.0, settingsProvider.volumeBoost);
            multiScreenProvider.playChannelAtDefaultPosition(
                channel, defaultPosition);

            // 分屏模式下导航到播放器页面，但不传递频道参数（由MultiScreenProvider处理播放）
            Navigator.pushNamed(
              context,
              AppRouter.player,
              arguments: {
                'channelUrl': '', // 空URL表示分屏模式
                'channelName': '',
                'channelLogo': null,
              },
            );
          } else {
            // 其他平台普通播放
            Navigator.pushNamed(
              context,
              AppRouter.player,
              arguments: {
                'channelUrl': channel.url,
                'channelName': channel.name,
                'channelLogo': channel.logoUrl,
              },
            );
          }
        } else {
          // 普通模式：导航到播放器页面并传递频道参数
          Navigator.pushNamed(
            context,
            AppRouter.player,
            arguments: {
              'channelUrl': channel.url,
              'channelName': channel.name,
              'channelLogo': channel.logoUrl,
            },
          );
        }
      },
      onLongPress: () => onShowOptions(channel),
    );
  }
}