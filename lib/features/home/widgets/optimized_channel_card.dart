import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/channel_card.dart';
import '../../../core/models/channel.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../epg/providers/epg_provider.dart';

/// 优化的频道卡片组件 - 使用 Selector 精确控制重建
class OptimizedChannelCard extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;
  final VoidCallback? onUp; // 添加onUp回调

  const OptimizedChannelCard({
    super.key,
    required this.channel,
    required this.onTap,
    this.onUp, // 添加onUp参数
  });

  @override
  Widget build(BuildContext context) {
    // 读取首页字体缩放设置（变化时触发重建）
    final fontScale = context.watch<SettingsProvider>().homeFontScale;
    // 使用 Selector 监听收藏状态和 EPG 数据变化
    return Selector2<FavoritesProvider, EpgProvider, ChannelCardData>(
      selector: (_, favProvider, epgProvider) {
        final currentProgram =
            epgProvider.getCurrentProgram(channel.epgId, channel.name);
        final nextProgram =
            epgProvider.getNextProgram(channel.epgId, channel.name);
        return ChannelCardData(
          isFavorite: favProvider.isFavorite(channel.id ?? 0),
          currentProgram: currentProgram?.title,
          nextProgram: nextProgram?.title,
        );
      },
      builder: (context, data, _) {
        return ChannelCard(
          name: channel.name,
          logoUrl: channel.logoUrl,
          channel: channel, // 传递完整的 channel 对象
          groupName: channel.groupName,
          currentProgram: data.currentProgram,
          nextProgram: data.nextProgram,
          isFavorite: data.isFavorite,
          fontScale: fontScale,
          onFavoriteToggle: () =>
              context.read<FavoritesProvider>().toggleFavorite(channel),
          onTap: onTap,
          onUp: onUp, // 传递onUp回调
        );
      },
    );
  }
}

/// 频道卡片数据，用于 Selector 比较
class ChannelCardData {
  final bool isFavorite;
  final String? currentProgram;
  final String? nextProgram;

  ChannelCardData({
    required this.isFavorite,
    this.currentProgram,
    this.nextProgram,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChannelCardData &&
        other.isFavorite == isFavorite &&
        other.currentProgram == currentProgram &&
        other.nextProgram == nextProgram;
  }

  @override
  int get hashCode => Object.hash(isFavorite, currentProgram, nextProgram);
}