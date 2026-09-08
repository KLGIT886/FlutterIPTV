import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/widgets/category_card.dart';

import '../providers/channel_provider.dart';
import 'background_test_indicator.dart';

/// 横屏分类栏 Delegate（固定在状态栏下方）
class LandscapeCategoryBarDelegate extends SliverPersistentHeaderDelegate {
  final ChannelProvider provider;
  final String? selectedGroup;
  final List<dynamic> channels;
  final Function(String?) onGroupSelected;
  final VoidCallback onTestChannels;
  final VoidCallback onShowBackgroundTest;
  final VoidCallback? onDeleteUnavailable;
  final double statusBarHeight;

  LandscapeCategoryBarDelegate({
    required this.provider,
    required this.selectedGroup,
    required this.channels,
    required this.onGroupSelected,
    required this.onTestChannels,
    required this.onShowBackgroundTest,
    this.onDeleteUnavailable,
    required this.statusBarHeight,
  });

  @override
  double get minExtent => 40.0 + statusBarHeight;

  @override
  double get maxExtent => 40.0 + statusBarHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: 40 + statusBarHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: Theme.of(context).brightness == Brightness.dark
              ? [
                  const Color(0xFF0A0A0A).withOpacity(0.95),
                  AppTheme.getPrimaryColor(context).withOpacity(0.15),
                ]
              : [
                  const Color(0xFFE0E0E0).withOpacity(0.95),
                  AppTheme.getPrimaryColor(context).withOpacity(0.12),
                ],
        ),
      ),
      child: Column(
        children: [
          // 顶部状态栏占位
          SizedBox(height: statusBarHeight - 10),
          // 分类栏内容
          Container(
            height: 40,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.getCardColor(context).withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // 左侧：横向滚动的分类列表
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: provider.groups.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        final isSelected = selectedGroup == null;
                        return _buildCategoryChip(
                          context: context,
                          name: AppStrings.of(context)?.allChannels ?? 'All',
                          count: provider.totalChannelCount,
                          isSelected: isSelected,
                          onTap: () => onGroupSelected(null),
                        );
                      } else {
                        final group = provider.groups[index - 1];
                        final isSelected = selectedGroup == group.name;
                        return _buildCategoryChip(
                          context: context,
                          name: group.name,
                          count: group.channelCount,
                          isSelected: isSelected,
                          onTap: () => onGroupSelected(group.name),
                        );
                      }
                    },
                  ),
                ),
                // 右侧：操作按钮
                _buildActions(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 分隔线
        Container(
          width: 1,
          height: 24,
          color: AppTheme.getCardColor(context).withOpacity(0.5),
          margin: const EdgeInsets.symmetric(horizontal: 4),
        ),
        // 后台测试进度
        BackgroundTestIndicator(onTap: onShowBackgroundTest),
        // 测试按钮
        IconButton(
          icon: const Icon(Icons.speed_rounded),
          iconSize: 18,
          padding: const EdgeInsets.all(6),
          color: channels.isEmpty
              ? AppTheme.getTextMuted(context).withOpacity(0.3)
              : AppTheme.getTextSecondary(context),
          onPressed: channels.isEmpty ? null : onTestChannels,
        ),
        // 删除失效频道按钮
        if (onDeleteUnavailable != null)
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            iconSize: 18,
            padding: const EdgeInsets.all(6),
            color: AppTheme.errorColor,
            onPressed: onDeleteUnavailable,
          ),
        // 频道数量
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceColor(context).withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${channels.length}',
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip({
    required BuildContext context,
    required String name,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: isSelected ? AppTheme.getGradient(context) : null,
              color: isSelected
                  ? null
                  : AppTheme.getCardColor(context).withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppTheme.getPrimaryColor(context)
                    : AppTheme.getGlassBorderColor(context),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CategoryCard.getIconForCategory(name),
                  size: 12,
                  color: isSelected
                      ? Colors.white
                      : AppTheme.getTextSecondary(context),
                ),
                const SizedBox(width: 4),
                Text(
                  name,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : AppTheme.getTextPrimary(context),
                    fontSize: 11,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.2)
                        : AppTheme.getCardColor(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppTheme.getTextMuted(context),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant LandscapeCategoryBarDelegate oldDelegate) {
    return oldDelegate.selectedGroup != selectedGroup ||
        oldDelegate.provider.groups.length != provider.groups.length ||
        oldDelegate.channels.length != channels.length;
  }
}