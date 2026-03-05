import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/platform/platform_detector.dart';

/// 可折叠的设置分组组件
class CollapsibleSettingsSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded;
  final FocusNode? focusNode;

  const CollapsibleSettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.initiallyExpanded = false, // 默认折叠
    this.focusNode,
  });

  @override
  State<CollapsibleSettingsSection> createState() => _CollapsibleSettingsSectionState();
}

class _CollapsibleSettingsSectionState extends State<CollapsibleSettingsSection> {
  late bool _isExpanded;
  late FocusNode _headerFocusNode;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _headerFocusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _headerFocusNode.dispose();
    }
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = PlatformDetector.isMobile;
    final isLandscape = isMobile && MediaQuery.of(context).size.width > 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分组标题（可点击折叠/展开）
        TVFocusable(
          focusNode: _headerFocusNode,
          onSelect: _toggleExpanded,
          focusScale: 1.0,
          showFocusBorder: false,
          builder: (context, isFocused, child) {
            return Container(
              margin: EdgeInsets.only(
                bottom: _isExpanded ? 12 : 8,
                top: 8,
              ),
              decoration: BoxDecoration(
                color: isFocused 
                    ? AppTheme.getFocusBackgroundColor(context)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: child,
            );
          },
          child: InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 12 : 16,
                vertical: isLandscape ? 8 : 12,
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isLandscape ? 6 : 8),
                    decoration: BoxDecoration(
                      color: AppTheme.getPrimaryColor(context).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(isLandscape ? 6 : 8),
                    ),
                    child: Icon(
                      widget.icon,
                      color: AppTheme.getPrimaryColor(context),
                      size: isLandscape ? 16 : 20,
                    ),
                  ),
                  SizedBox(width: isLandscape ? 12 : 16),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontSize: isLandscape ? 14 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.getTextSecondary(context),
                    size: isLandscape ? 20 : 24,
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // 展开的内容
        if (_isExpanded)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: widget.children,
            ),
          ),
      ],
    );
  }
}
