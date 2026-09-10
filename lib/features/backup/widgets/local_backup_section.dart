import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/app_restart_helper.dart';
import '../../../core/widgets/tv_focusable.dart';
import 'backup_ui_helpers.dart';
import 'backup_list_item.dart';
import '../providers/backup_provider.dart';

/// 本地备份区域组件
class LocalBackupSection extends StatefulWidget {
  const LocalBackupSection({super.key});

  @override
  State<LocalBackupSection> createState() => _LocalBackupSectionState();
}

class _LocalBackupSectionState extends State<LocalBackupSection> {
  String _backupDirectory = '';
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadBackupDirectory();
  }

  Future<void> _loadBackupDirectory() async {
    try {
      final provider = context.read<BackupProvider>();
      final backupDir = await provider.getBackupDirectoryPath();
      if (mounted) {
        setState(() {
          _backupDirectory = backupDir;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _backupDirectory = 'Error loading directory';
        });
      }
    }
  }

  Future<void> _selectBackupDirectory(BuildContext context) async {
    try {
      final result = await FilePicker.getDirectoryPath(
        dialogTitle: '选择备份目录',
      );

      if (result != null) {
        final provider = context.read<BackupProvider>();
        final success = await provider.setBackupDirectory(result);
        
        if (success && mounted) {
          setState(() {
            _backupDirectory = result;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('备份目录已设置为: $result'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('设置备份目录失败: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context)!;
    final provider = context.watch<BackupProvider>();
    final backgroundColor = AppTheme.getBackgroundColor(context);
    final cardColor = AppTheme.getCardColor(context);
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);
    final primaryColor = AppTheme.getPrimaryColor(context);

    // 获取响应式样式
    final style = backupResponsiveStyle(context);

    return Container(
      color: backgroundColor,
      child: ListView(
        padding: EdgeInsets.all(style['containerPadding']),
        children: [
          // 备份目录卡片
          Container(
            padding: EdgeInsets.all(style['cardPadding']),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: AppTheme.getGlassBorderColor(context),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.folder_rounded, color: primaryColor, size: style['iconSize']),
                    SizedBox(width: style['spacing'] / 2),
                    Text(
                      strings.backupInfo,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: style['titleFontSize'],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: style['spacing'] * 0.6),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: style['isLandscape'] ? 8.0 : 16.0,
                    vertical: style['isLandscape'] ? 5.0 : 12.0,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.getGlassColor(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _backupDirectory.isEmpty ? 'Loading...' : _backupDirectory,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: style['bodyFontSize'],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: style['spacing']),
                Row(
                  children: [
                    Expanded(
                      child: TVFocusable(
                        focusScale: 1.0,
                        showFocusBorder: false,
                        onSelect: () => _selectBackupDirectory(context),
                        builder: (context, isFocused, child) {
                          return Container(
                            decoration: BoxDecoration(
                              color: isFocused ? primaryColor.withOpacity(0.1) : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            ),
                            child: child,
                          );
                        },
                        child: OutlinedButton.icon(
                          onPressed: () => _selectBackupDirectory(context),
                          icon: Icon(Icons.folder_open_rounded, size: style['iconSize']),
                          label: Text(
                            strings.browse,
                            style: TextStyle(fontSize: style['bodyFontSize']),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textPrimary,
                            side: BorderSide(color: textPrimary.withOpacity(0.3)),
                            padding: EdgeInsets.symmetric(
                              horizontal: style['isLandscape'] ? 10.0 : 20.0,
                              vertical: style['isLandscape'] ? 5.0 : 14.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: style['spacing'] * 0.75),
                    Expanded(
                      child: TVFocusable(
                        focusScale: 1.0,
                        showFocusBorder: false,
                        onSelect: () => _createBackup(context),
                        builder: (context, isFocused, child) {
                          return Container(
                            decoration: BoxDecoration(
                              color: isFocused ? primaryColor.withOpacity(0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            ),
                            child: child,
                          );
                        },
                        child: ElevatedButton.icon(
                          onPressed: () => _createBackup(context),
                          icon: Icon(Icons.add_rounded, size: style['iconSize']),
                          label: Text(
                            strings.createBackup,
                            style: TextStyle(fontSize: style['bodyFontSize']),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: style['isLandscape'] ? 10.0 : 20.0,
                              vertical: style['isLandscape'] ? 5.0 : 14.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: style['sectionSpacing']),

          // 备份列表标题和操作
          Row(
            children: [
              Text(
                strings.backupList,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: style['titleFontSize'],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TVFocusable(
                focusScale: 1.0,
                showFocusBorder: false,
                onSelect: _isRefreshing ? null : () => _refreshLocalBackups(context),
                builder: (context, isFocused, child) {
                  return Container(
                    decoration: BoxDecoration(
                      color: isFocused && !_isRefreshing ? primaryColor.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: child,
                  );
                },
                child: OutlinedButton.icon(
                  onPressed: _isRefreshing ? null : () => _refreshLocalBackups(context),
                  icon: _isRefreshing
                      ? SizedBox(
                          width: style['iconSize'],
                          height: style['iconSize'],
                          child: const CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.refresh_rounded, size: style['iconSize']),
                  label: Text(
                    strings.refresh,
                    style: TextStyle(fontSize: style['bodyFontSize']),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textPrimary,
                    side: BorderSide(color: textPrimary.withOpacity(0.3)),
                    padding: EdgeInsets.symmetric(
                      horizontal: style['isLandscape'] ? 8.0 : 16.0,
                      vertical: style['isLandscape'] ? 5.0 : 12.0,
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: style['spacing']),

          // 备份文件列表
          if (provider.localBackups.isEmpty)
            SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.backup_rounded,
                      size: style['iconSize'] * 3.2,
                      color: textSecondary.withOpacity(0.3),
                    ),
                    SizedBox(height: style['spacing']),
                    Text(
                      strings.noBackupsYet,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: style['titleFontSize'],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...provider.localBackups.asMap().entries.map((entry) =>
              _buildBackupItem(context, entry.value, entry.key)
            ),
        ],
      ),
    );
  }

  Widget _buildBackupItem(BuildContext context, dynamic backup, int index) {
    return BackupListItem(
      backup: backup,
      index: index,
      headerIcon: Icons.archive_rounded,
      restoreIcon: Icons.restore_rounded,
      onRestore: () => _restoreBackup(context, backup.path),
      onDelete: () => _deleteBackup(context, backup.path),
    );
  }

  Future<void> _refreshLocalBackups(BuildContext context) async {
    setState(() => _isRefreshing = true);
    final provider = context.read<BackupProvider>();
    await provider.loadLocalBackups();
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _createBackup(BuildContext context) async {
    final strings = AppStrings.of(context)!;
    final provider = context.read<BackupProvider>();
    final style = backupResponsiveStyle(context);

    // 显示 loading 对话框
    showBackupLoadingDialog(context);

    final success = await provider.createLocalBackup(
      message: '正在创建本地备份...',
    );

    // 关闭 loading 对话框
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_rounded : Icons.error_rounded,
                color: Colors.white,
              ),
              SizedBox(width: style['spacing'] * 0.75),
              Text(success ? strings.backupCreated : strings.backupFailed),
            ],
          ),
          backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
        ),
      );
    }
  }

  Future<void> _restoreBackup(BuildContext context, String filePath) async {
    final strings = AppStrings.of(context)!;
    final provider = context.read<BackupProvider>();
    final style = backupResponsiveStyle(context);

    // 验证备份文件
    final metadata = await provider.validateBackup(filePath);
    if (metadata == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.restoreFailed),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }

    // 显示确认对话框
    if (context.mounted) {
      final cardColor = AppTheme.getCardColor(context);
      final textPrimary = AppTheme.getTextPrimary(context);
      final textSecondary = AppTheme.getTextSecondary(context);
      final primaryColor = AppTheme.getPrimaryColor(context);
      
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color: AppTheme.warningColor,
                  size: style['iconSize'] * 1.2,
                ),
              ),
              SizedBox(width: style['spacing'] * 0.75),
              Text(
                strings.restoreWarning,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: style['titleFontSize'],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.restoreWarningMessage,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: style['bodyFontSize'],
                  height: 1.5,
                ),
              ),
              SizedBox(height: style['spacing'] * 1.25),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.getGlassColor(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(
                    color: AppTheme.getGlassBorderColor(context),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      context,
                      Icons.info_outline_rounded,
                      strings.appVersion,
                      metadata.appVersion,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      context,
                      Icons.access_time_rounded,
                      strings.backupTime,
                      metadata.formattedTimestamp,
                    ),
                    if (metadata.databaseVersion < 8) ...[
                      SizedBox(height: style['spacing'] * 0.75),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.upgrade_rounded,
                              color: AppTheme.warningColor,
                              size: style['iconSize'] * 0.9,
                            ),
                            SizedBox(width: style['spacing'] / 2),
                            Expanded(
                              child: Text(
                                strings.willAutoMigrate,
                                style: TextStyle(
                                  color: AppTheme.warningColor,
                                  fontSize: style['smallFontSize'],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                strings.cancel,
                style: TextStyle(color: textSecondary),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: Icon(Icons.restore_rounded, size: style['iconSize']),
              label: Text(strings.restoreConfirm),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        ServiceLocator.log.i('用户确认恢复', tag: 'LocalBackupSection');
        
        // 显示 loading 对话框
        showBackupLoadingDialog(context);
        
        // 使用 Provider 恢复
        final success = await provider.restoreFromLocal(
          filePath,
          message: '正在恢复备份...',
        );
        
        // 关闭 loading 对话框
        if (context.mounted) {
          Navigator.of(context).pop();
        }
        
        if (context.mounted) {
          if (success) {
            ServiceLocator.log.i('恢复成功，显示重启对话框', tag: 'LocalBackupSection');
            // 恢复成功，显示提示并重启应用
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => AlertDialog(
                backgroundColor: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.successColor,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: style['spacing'] * 0.75),
                    Text(
                      strings.success,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: style['titleFontSize'],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      strings.restoreSuccess,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: style['bodyFontSize'],
                      ),
                    ),
                    SizedBox(height: style['spacing']),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.getGlassColor(context),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        border: Border.all(
                          color: AppTheme.getGlassBorderColor(context),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.restart_alt_rounded,
                            color: AppTheme.infoColor,
                            size: style['iconSize'],
                          ),
                          SizedBox(width: style['spacing'] * 0.75),
                          Expanded(
                            child: Text(
                              AppRestartHelper.getRestartMessage(),
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: style['smallFontSize'],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      ServiceLocator.log.i('用户点击重启按钮', tag: 'LocalBackupSection');
                      Navigator.pop(dialogContext);
                      await Future.delayed(const Duration(milliseconds: 500));
                      ServiceLocator.log.i('调用 AppRestartHelper.restartApp()', tag: 'LocalBackupSection');
                      await AppRestartHelper.restartApp();
                    },
                    icon: Icon(Icons.restart_alt_rounded, size: style['iconSize']),
                    label: Text(AppRestartHelper.getRestartButtonText()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                  ),
                ],
              ),
            );
          } else {
            ServiceLocator.log.e('恢复失败: ${provider.error}', tag: 'LocalBackupSection');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(provider.error ?? strings.restoreFailed),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _deleteBackup(BuildContext context, String filePath) async {
    final strings = AppStrings.of(context)!;
    final cardColor = AppTheme.getCardColor(context);
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);
    final style = backupResponsiveStyle(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(
                Icons.delete_rounded,
                color: AppTheme.errorColor,
                size: style['iconSize'] * 1.2,
              ),
            ),
            SizedBox(width: style['spacing'] * 0.75),
            Text(
              strings.deleteBackup,
              style: TextStyle(
                color: textPrimary,
                fontSize: style['titleFontSize'],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          strings.deleteBackupConfirm,
          style: TextStyle(
            color: textSecondary,
            fontSize: style['bodyFontSize'],
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              strings.cancel,
              style: TextStyle(color: textSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: Icon(Icons.delete_rounded, size: style['iconSize']),
            label: Text(strings.delete),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = context.read<BackupProvider>();
      final success = await provider.deleteLocalBackup(filePath);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  success ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: Colors.white,
                ),
                SizedBox(width: style['spacing'] * 0.75),
                Text(success ? strings.backupDeleted : strings.error),
              ],
            ),
            backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
          ),
        );
      }
    }
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);
    final style = backupResponsiveStyle(context);

    return Row(
      children: [
        Icon(icon, size: style['iconSize'], color: textSecondary),
        SizedBox(width: style['spacing'] / 2),
        Text(
          '$label: ',
          style: TextStyle(
            color: textSecondary,
            fontSize: style['smallFontSize'],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: textPrimary,
              fontSize: style['smallFontSize'],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

