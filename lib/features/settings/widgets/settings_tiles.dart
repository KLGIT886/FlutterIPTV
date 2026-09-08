import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/platform/platform_detector.dart';

/// 设置页通用「列表项/开关项/选择项/输入项/动作项/分隔线」构造方法。
/// 从 `settings_screen.dart` 纯搬移：仅依赖 context 与入参，不依赖 State 字段。
/// 纯搬移，未改任何逻辑与样式。

Widget buildDivider() {
  return Builder(
    builder: (context) => Divider(
      color: AppTheme.getCardColor(context),
      height: 1,
      indent: 56,
    ),
  );
}

Widget buildSwitchTile(
  BuildContext context, {
  required String title,
  required String subtitle,
  required IconData icon,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  final isMobile = PlatformDetector.isMobile;
  final isLandscape = isMobile && MediaQuery.of(context).size.width > 600;

  return TVFocusable(
    onSelect: () => onChanged(!value),
    focusScale: 1.0,
    showFocusBorder: false,
    builder: (context, isFocused, child) {
      return Container(
        decoration: BoxDecoration(
          color: isFocused
              ? AppTheme.getFocusBackgroundColor(context)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      );
    },
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 12 : 16,
        vertical: isLandscape ? 8 : 14,
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
              icon,
              color: AppTheme.getPrimaryColor(context),
              size: isLandscape ? 16 : 20,
            ),
          ),
          SizedBox(width: isLandscape ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontSize: isLandscape ? 13 : 15, // 横屏时字体更小
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppTheme.getTextMuted(context),
                    fontSize: isLandscape ? 10 : 12, // 横屏时字体更小
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: isLandscape ? 0.8 : 1.0, // 横屏时开关更小
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.getPrimaryColor(context),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget buildSelectTile(
  BuildContext context, {
  required String title,
  required String subtitle,
  required IconData icon,
  required VoidCallback onTap,
}) {
  final isMobile = PlatformDetector.isMobile;
  final isLandscape = isMobile && MediaQuery.of(context).size.width > 600;

  return TVFocusable(
    onSelect: onTap,
    focusScale: 1.0,
    showFocusBorder: false,
    builder: (context, isFocused, child) {
      return Container(
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
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 12 : 16,
          vertical: isLandscape ? 8 : 14,
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
                icon,
                color: AppTheme.getPrimaryColor(context),
                size: isLandscape ? 16 : 20,
              ),
            ),
            SizedBox(width: isLandscape ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontSize: isLandscape ? 13 : 15, // 横屏时字体更小
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.getTextMuted(context),
                      fontSize: isLandscape ? 10 : 12, // 横屏时字体更小
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.getTextMuted(context),
              size: isLandscape ? 18 : 24, // 横屏时图标更小
            ),
          ],
        ),
      ),
    ),
  );
}

Widget buildInputTile(
  BuildContext context, {
  required String title,
  required String subtitle,
  required IconData icon,
  required VoidCallback onTap,
}) {
  return buildSelectTile(
    context,
    title: title,
    subtitle: subtitle,
    icon: icon,
    onTap: onTap,
  );
}

Widget buildActionTile(
  BuildContext context, {
  required String title,
  required String subtitle,
  required IconData icon,
  required VoidCallback onTap,
  bool isDestructive = false,
}) {
  final isMobile = PlatformDetector.isMobile;
  final isLandscape = isMobile && MediaQuery.of(context).size.width > 600;

  return TVFocusable(
    onSelect: onTap,
    focusScale: 1.0,
    showFocusBorder: false,
    builder: (context, isFocused, child) {
      return Container(
        decoration: BoxDecoration(
          color: isFocused
              ? (isDestructive
                  ? AppTheme.errorColor.withOpacity(0.1)
                  : AppTheme.getFocusBackgroundColor(context))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      );
    },
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 12 : 16,
          vertical: isLandscape ? 8 : 14,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isLandscape ? 6 : 8),
              decoration: BoxDecoration(
                color: (isDestructive
                        ? AppTheme.errorColor
                        : AppTheme.getPrimaryColor(context))
                    .withOpacity(0.15),
                borderRadius: BorderRadius.circular(isLandscape ? 6 : 8),
              ),
              child: Icon(
                icon,
                color: isDestructive
                    ? AppTheme.errorColor
                    : AppTheme.getPrimaryColor(context),
                size: isLandscape ? 16 : 20,
              ),
            ),
            SizedBox(width: isLandscape ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDestructive
                          ? AppTheme.errorColor
                          : AppTheme.getTextPrimary(context),
                      fontSize: isLandscape ? 13 : 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.getTextMuted(context),
                      fontSize: isLandscape ? 10 : 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget buildInfoTile(
  BuildContext context, {
  required String title,
  required String value,
  required IconData icon,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.getTextMuted(context).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.getTextMuted(context), size: 20),
        ),
        const SizedBox(width: 16),
        Text(
          title,
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: AppTheme.getTextSecondary(context),
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
}
