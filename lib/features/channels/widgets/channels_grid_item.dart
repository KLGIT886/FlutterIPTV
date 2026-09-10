import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/channel_card.dart';
import '../../../core/services/epg_service.dart';
import '../../../core/services/channel_playback.dart';
import '../../../core/models/channel.dart';

import '../providers/channel_provider.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../epg/providers/epg_provider.dart';

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
        await playChannelFromList(
          context,
          channel,
          logTag: 'ChannelsScreen',
          registerNativeProviders: true,
          recordWatchHistory: true,
        );
      },
      onLongPress: () => onShowOptions(channel),
    );
  }
}