import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/widgets/tv_focusable.dart';
import 'backup_ui_helpers.dart';

/// 备份列表中的单条记录（WebDAV 远程 / 本地备份共用）。
///
/// 此前两份 `_buildBackupItem` 约 90% 相同，仅在来源图标、恢复图标与少量
/// 内边距/间距上不一致；此处统一为一个组件，通过 [headerIcon]/[restoreIcon]/
/// [onRestore]/[onDelete] 区分来源，一并抹平这些细微差异。
class BackupListItem extends StatelessWidget {
  final dynamic backup;
  final int index;
  final IconData headerIcon;
  final IconData restoreIcon;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const BackupListItem({
    super.key,
    required this.backup,
    required this.index,
    required this.headerIcon,
    required this.restoreIcon,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = AppTheme.getCardColor(context);
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);
    final primaryColor = AppTheme.getPrimaryColor(context);
    final strings = AppStrings.of(context)!;
    final style = backupResponsiveStyle(context);

    return Container(
      margin: EdgeInsets.only(bottom: style['isLandscape'] ? 8.0 : 12.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.getGlassBorderColor(context),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          onTap: onRestore,
          child: Padding(
            padding: EdgeInsets.all(style['isLandscape'] ? 10.0 : 16.0),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(style['isLandscape'] ? 8.0 : 12.0),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(
                    headerIcon,
                    color: primaryColor,
                    size: style['iconSize'] * 1.2,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        backup.name,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: style['bodyFontSize'],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: style['smallFontSize'] + 1,
                              color: textSecondary),
                          SizedBox(width: style['spacing'] / 4),
                          Text(
                            backup.formattedDate,
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: style['smallFontSize'],
                            ),
                          ),
                          SizedBox(width: style['spacing']),
                          Icon(Icons.storage_rounded,
                              size: style['smallFontSize'] + 1,
                              color: textSecondary),
                          SizedBox(width: style['spacing'] / 4),
                          Text(
                            backup.formattedSize,
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: style['smallFontSize'],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TVFocusable(
                  autofocus: index == 0,
                  focusScale: 1.0,
                  showFocusBorder: false,
                  onSelect: onRestore,
                  builder: (context, isFocused, child) {
                    return Container(
                      decoration: BoxDecoration(
                        color: isFocused
                            ? primaryColor.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: child,
                    );
                  },
                  child: OutlinedButton.icon(
                    onPressed: onRestore,
                    icon: Icon(restoreIcon, size: style['iconSize']),
                    label: Text(
                      strings.restoreBackup,
                      style: TextStyle(fontSize: style['bodyFontSize']),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor),
                      padding: EdgeInsets.symmetric(
                        horizontal: style['isLandscape'] ? 10.0 : 16.0,
                        vertical: style['isLandscape'] ? 6.0 : 10.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TVFocusable(
                  focusScale: 1.0,
                  showFocusBorder: false,
                  onSelect: onDelete,
                  builder: (context, isFocused, child) {
                    return Container(
                      decoration: BoxDecoration(
                        color: isFocused
                            ? AppTheme.errorColor.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: child,
                    );
                  },
                  child: IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: AppTheme.errorColor,
                    tooltip: strings.delete,
                    iconSize: style['iconSize'],
                    padding: EdgeInsets.all(style['isLandscape'] ? 4.0 : 8.0),
                    constraints: BoxConstraints(
                      minWidth: style['isLandscape'] ? 28.0 : 48.0,
                      minHeight: style['isLandscape'] ? 28.0 : 48.0,
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
}
