import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/platform/platform_detector.dart';
import '../providers/backup_provider.dart';

/// 备份操作进行中的模态 loading 对话框（WebDAV / 本地备份共用）。
void showBackupLoadingDialog(BuildContext context) {
  final textPrimary = AppTheme.getTextPrimary(context);
  final textSecondary = AppTheme.getTextSecondary(context);
  final cardColor = AppTheme.getCardColor(context);

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: Consumer<BackupProvider>(
        builder: (context, provider, child) {
          return AlertDialog(
            backgroundColor: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(),
                ),
                const SizedBox(height: 24),
                Text(
                  provider.progressMessage,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (provider.progress > 0) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: provider.progress),
                  const SizedBox(height: 8),
                  Text(
                    '${(provider.progress * 100).toInt()}%',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ),
  );
}

/// 备份区块的响应式样式（横屏 / 电视 / 手机适配），WebDAV 与本地备份共用。
Map<String, dynamic> backupResponsiveStyle(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;
  final isMobile = PlatformDetector.isMobile;
  final isLandscape =
      isMobile && screenWidth > 600 && screenWidth < 900 && screenHeight < screenWidth;
  final isTV = PlatformDetector.isTV;

  return {
    'isLandscape': isLandscape,
    'containerPadding': isLandscape ? 6.0 : (isTV ? 32.0 : 20.0),
    'cardPadding': isLandscape ? 8.0 : 20.0,
    'titleFontSize': isLandscape ? 10.5 : (isTV ? 18.0 : 16.0),
    'bodyFontSize': isLandscape ? 9.5 : (isTV ? 16.0 : 14.0),
    'smallFontSize': isLandscape ? 8.5 : (isTV ? 14.0 : 13.0),
    'iconSize': isLandscape ? 13.0 : 20.0,
    'spacing': isLandscape ? 4.0 : (isTV ? 24.0 : 16.0),
    'sectionSpacing': isLandscape ? 8.0 : 24.0,
    'buttonPadding': EdgeInsets.symmetric(
      horizontal: isLandscape ? 8.0 : 16.0,
      vertical: isLandscape ? 4.0 : 12.0,
    ),
  };
}
