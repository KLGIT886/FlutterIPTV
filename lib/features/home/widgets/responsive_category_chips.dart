import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/widgets/category_card.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/utils/throttled_state_mixin.dart';

/// 响应式分类标签组件 - 根据宽度自适应，超出时折叠
class ResponsiveCategoryChips extends StatefulWidget {
  final List<dynamic> groups;
  final Function(String) onGroupTap;

  const ResponsiveCategoryChips({
    super.key,
    required this.groups,
    required this.onGroupTap,
  });

  @override
  State<ResponsiveCategoryChips> createState() =>
      ResponsiveCategoryChipsState();
}

class ResponsiveCategoryChipsState extends State<ResponsiveCategoryChips>
    with ThrottledStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = PlatformDetector.isMobile;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = isMobile ? 12.0 : 24.0;
        final availableWidth = constraints.maxWidth - horizontalPadding * 2;

        // 计算每个 chip 的大致宽度（图标 + 文字 + padding）
        // 手机端使用更小的估算宽度
        final estimatedChipWidth = isMobile ? 75.0 : 110.0;
        final maxVisibleCount = (availableWidth / estimatedChipWidth).floor();

        // 如果所有分类都能显示，直接用 Wrap
        if (widget.groups.length <= maxVisibleCount || _isExpanded) {
          return _buildExpandedView(isMobile, horizontalPadding);
        }

        // 否则显示部分 + 展开按钮
        return _buildCollapsedView(
            maxVisibleCount, isMobile, horizontalPadding);
      },
    );
  }

  Widget _buildExpandedView(bool isMobile, double horizontalPadding) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: isMobile ? 6 : 8,
          runSpacing: isMobile ? 6 : 8,
          alignment: WrapAlignment.start,
          children: [
            ...widget.groups.map((group) => _buildChip(group.name, isMobile)),
            if (widget.groups.length > 6) _buildCollapseButton(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedView(
      int maxVisible, bool isMobile, double horizontalPadding) {
    // 至少显示 4 个，留一个位置给展开按钮
    final visibleCount = (maxVisible - 1).clamp(3, widget.groups.length);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: isMobile ? 6 : 8,
          runSpacing: isMobile ? 6 : 8,
          alignment: WrapAlignment.start,
          children: [
            ...widget.groups
                .take(visibleCount)
                .map((group) => _buildChip(group.name, isMobile)),
            _buildExpandButton(widget.groups.length - visibleCount, isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String name, bool isMobile) {
    return TVFocusable(
      onSelect: () => widget.onGroupTap(name),
      focusScale: 1.0,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return Container(
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 12,
              vertical: isMobile ? 3 : 8), // 手机端从5减少到3
          decoration: BoxDecoration(
            gradient: isFocused
                ? AppTheme.getGradient(context)
                : AppTheme.getSoftGradient(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
                color: isFocused
                    ? AppTheme.getPrimaryColor(context)
                    : AppTheme.getGlassBorderColor(context)),
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CategoryCard.getIconForCategory(name),
              size: isMobile ? 12 : 14,
              color: AppTheme.getTextSecondary(context)),
          SizedBox(width: isMobile ? 4 : 6),
          Text(name,
              style: TextStyle(
                  color: AppTheme.getTextSecondary(context),
                  fontSize: isMobile ? 10 : 12)),
        ],
      ),
    );
  }

  Widget _buildExpandButton(int hiddenCount, bool isMobile) {
    return TVFocusable(
      onSelect: () => immediateSetState(() => _isExpanded = true), // 立即更新展开状态
      focusScale: 1.0,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return Container(
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 12,
              vertical: isMobile ? 3 : 8), // 手机端从5减少到3
          decoration: BoxDecoration(
            gradient: isFocused
                ? AppTheme.getGradient(context)
                : AppTheme.getSoftGradient(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
                color: isFocused
                    ? AppTheme.getPrimaryColor(context)
                    : AppTheme.getGlassBorderColor(context)),
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.more_horiz_rounded,
              size: isMobile ? 12 : 14,
              color: AppTheme.getTextSecondary(context)),
          SizedBox(width: isMobile ? 3 : 4),
          Text('+$hiddenCount',
              style: TextStyle(
                  color: AppTheme.getTextSecondary(context),
                  fontSize: isMobile ? 10 : 12)),
        ],
      ),
    );
  }

  Widget _buildCollapseButton(bool isMobile) {
    return TVFocusable(
      onSelect: () => immediateSetState(() => _isExpanded = false), // 立即更新折叠状态
      focusScale: 1.0,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return Container(
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 12,
              vertical: isMobile ? 3 : 8), // 手机端从5减少到3
          decoration: BoxDecoration(
            gradient: isFocused
                ? AppTheme.getGradient(context)
                : AppTheme.getSoftGradient(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
                color: isFocused
                    ? AppTheme.getPrimaryColor(context)
                    : AppTheme.getGlassBorderColor(context)),
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.unfold_less_rounded,
              size: isMobile ? 12 : 14,
              color: AppTheme.getTextSecondary(context)),
          SizedBox(width: isMobile ? 3 : 4),
          Text(AppStrings.of(context)?.collapse ?? 'Collapse',
              style: TextStyle(
                  color: AppTheme.getTextSecondary(context),
                  fontSize: isMobile ? 10 : 12)),
        ],
      ),
    );
  }
}