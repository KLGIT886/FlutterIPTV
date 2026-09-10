import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/widgets/channel_logo_widget.dart';
import '../../../core/widgets/auto_scroll_text.dart';

/// 收藏列表中的单个收藏卡片（支持拖拽排序、悬停/聚焦自动滚动）。
class FavoriteCardWrapper extends StatefulWidget {
  final int index;
  final dynamic channel;
  final bool isLandscape;
  final VoidCallback onPlayChannel;
  final VoidCallback onRemoveFavorite;

  const FavoriteCardWrapper({
    super.key,
    required this.index,
    required this.channel,
    required this.isLandscape,
    required this.onPlayChannel,
    required this.onRemoveFavorite,
  });

  @override
  State<FavoriteCardWrapper> createState() => FavoriteCardWrapperState();
}

class FavoriteCardWrapperState extends State<FavoriteCardWrapper> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return TVFocusable(
      autofocus: widget.index == 0,
      onSelect: widget.onPlayChannel,
      onFocus: () => setState(() => _isFocused = true),
      onBlur: () => setState(() => _isFocused = false),
      focusScale: 1.02,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return AnimatedContainer(
          duration: AppTheme.animationFast,
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(widget.isLandscape ? 12 : 16),
            border: Border.all(
              color: isFocused
                  ? AppTheme.getPrimaryColor(context)
                  : Colors.transparent,
              width: isFocused ? 2 : 0,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: AppTheme.getPrimaryColor(context).withOpacity(0.2),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.all(widget.isLandscape ? 6 : 10),
        child: Row(
          children: [
            // Drag Handle
            ReorderableDragStartListener(
              index: widget.index,
              child: Container(
                padding: EdgeInsets.all(widget.isLandscape ? 4 : 6),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  color: AppTheme.textMuted,
                  size: widget.isLandscape ? 14 : 18,
                ),
              ),
            ),

            SizedBox(width: widget.isLandscape ? 6 : 8),

            // Channel Logo
            ChannelLogoWidget(
              channel: widget.channel,
              width: widget.isLandscape ? 48 : 64,
              height: widget.isLandscape ? 36 : 48,
              fit: BoxFit.contain,
              borderRadius: BorderRadius.circular(widget.isLandscape ? 8 : 10),
            ),

            SizedBox(width: widget.isLandscape ? 10 : 16),

            // Channel Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AutoScrollText(
                    text: widget.channel.name,
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontSize: widget.isLandscape ? 12 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                    forceScroll: _isHovered || _isFocused,
                  ),
                  if (widget.channel.groupName != null) ...[
                    SizedBox(height: widget.isLandscape ? 1 : 2),
                    AutoScrollText(
                      text: widget.channel.groupName!,
                      style: TextStyle(
                        color: AppTheme.getTextSecondary(context),
                        fontSize: widget.isLandscape ? 10 : 11,
                      ),
                      forceScroll: _isHovered || _isFocused,
                    ),
                  ],
                ],
              ),
            ),

            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Play Button
                TVFocusable(
                  onSelect: widget.onPlayChannel,
                  child: Container(
                    padding: EdgeInsets.all(widget.isLandscape ? 6 : 8),
                    decoration: BoxDecoration(
                      color: AppTheme.getPrimaryColor(context).withOpacity(0.2),
                      borderRadius:
                          BorderRadius.circular(widget.isLandscape ? 6 : 8),
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: AppTheme.getPrimaryColor(context),
                      size: widget.isLandscape ? 16 : 20,
                    ),
                  ),
                ),
                SizedBox(width: widget.isLandscape ? 4 : 6),

                // Remove Button
                TVFocusable(
                  onSelect: widget.onRemoveFavorite,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(widget.isLandscape ? 6 : 8),
                    ),
                    child: Icon(
                      Icons.favorite,
                      color: AppTheme.errorColor,
                      size: widget.isLandscape ? 16 : 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
