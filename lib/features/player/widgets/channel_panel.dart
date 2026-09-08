import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../core/models/channel_group.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../channels/providers/channel_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/player_provider.dart';

/// 播放界面左侧的分类面板 + 频道列表（用于切换频道）。
///
/// 分类/频道状态由父层通过回调注入（[selectedCategory]、[onCategorySelected]、
/// [onBack]、[onClose]），滚动控制器亦由父层持有以便外部定位当前频道。
class ChannelPanel extends StatelessWidget {
  final List<ChannelGroup> groups;
  final String? selectedCategory;
  final ScrollController categoryScrollController;
  final ScrollController channelScrollController;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onBack;
  final VoidCallback onClose;

  const ChannelPanel({
    super.key,
    required this.groups,
    required this.selectedCategory,
    required this.categoryScrollController,
    required this.channelScrollController,
    required this.onCategorySelected,
    required this.onBack,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      child: Row(
        children: [
          _buildCategoryList(context),
          if (selectedCategory != null) _buildChannelList(context),
        ],
      ),
    );
  }

  /// 左侧分类列表。
  Widget _buildCategoryList(BuildContext context) {
    return Container(
      width: 180,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xE6000000),
            Color(0x99000000),
            Colors.transparent,
          ],
          stops: [0.0, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                AppStrings.of(context)?.categories ?? 'Categories',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: categoryScrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  final isSelected = selectedCategory == group.name;
                  return TVFocusable(
                    autofocus: index == 0 && selectedCategory == null,
                    onSelect: () => onCategorySelected(group.name),
                    focusScale: 1.0,
                    showFocusBorder: false,
                    builder: (context, isFocused, child) {
                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: (isFocused || isSelected)
                              ? AppTheme.getGradient(context)
                              : null,
                          color: (isFocused || isSelected)
                              ? null
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: child,
                      );
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${group.channelCount}',
                          style: const TextStyle(
                              color: Color(0x99FFFFFF), fontSize: 11),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 右侧频道列表（选中分类后显示）。
  Widget _buildChannelList(BuildContext context) {
    final channelProvider = context.read<ChannelProvider>();
    final playerProvider = context.read<PlayerProvider>();
    final channels = channelProvider.getChannelsByGroup(selectedCategory!);
    final currentChannel = playerProvider.currentChannel;

    return Container(
      width: 220,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xCC000000),
            Color(0x66000000),
            Colors.transparent,
          ],
          stops: [0.0, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: const Icon(Icons.arrow_back_ios,
                        color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedCategory!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: channelScrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: channels.length,
                itemBuilder: (context, index) {
                  final channel = channels[index];
                  final isPlaying = currentChannel?.id == channel.id;
                  return TVFocusable(
                    autofocus: isPlaying, // 当前播放的频道自动获取焦点
                    onSelect: () {
                      // 保存上次播放的频道 ID
                      final settingsProvider = context.read<SettingsProvider>();
                      if (settingsProvider.rememberLastChannel &&
                          channel.id != null) {
                        settingsProvider.setLastChannelId(channel.id);
                      }

                      // 切换到该频道并关闭面板
                      playerProvider.playChannel(channel);
                      onClose();
                    },
                    focusScale: 1.0,
                    showFocusBorder: false,
                    builder: (context, isFocused, child) {
                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          gradient:
                              isFocused ? AppTheme.getGradient(context) : null,
                          color: isPlaying && !isFocused
                              ? const Color(0x33E91E63)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: child,
                      );
                    },
                    child: Row(
                      children: [
                        if (isPlaying)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(Icons.play_arrow,
                                color: AppTheme.getPrimaryColor(context),
                                size: 16),
                          ),
                        Expanded(
                          child: Text(
                            channel.name,
                            style: TextStyle(
                              color: isPlaying
                                  ? AppTheme.getPrimaryColor(context)
                                  : Colors.white,
                              fontSize: 13,
                              fontWeight: isPlaying
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
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