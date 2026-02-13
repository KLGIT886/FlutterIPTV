import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_update.dart';
import '../i18n/app_strings.dart';
// 注释掉未使用的导入
// import '../services/update_service.dart';

class UpdateDialog extends StatelessWidget {
  final AppUpdate update;
  final VoidCallback onUpdate;
  final VoidCallback onCancel;

  const UpdateDialog({
    super.key,
    required this.update,
    required this.onUpdate,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
    final maxHeight = MediaQuery.of(context).size.height * (isLandscape ? 0.7 : 0.8);
    
    return Dialog(
      backgroundColor: AppTheme.getSurfaceColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight,
          maxWidth: isLandscape ? 500 : double.infinity,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 可滚动的内容区域
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题和图标
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.system_update,
                            color: AppTheme.primaryColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.of(context)?.newVersionAvailable ?? 'New version available',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'v${update.version}',
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 发布说明
                    Text(
                      AppStrings.of(context)?.whatsNew ?? 'What\'s new',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatReleaseNotes(update.releaseNotes),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 固定在底部的按钮组
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                color: AppTheme.getSurfaceColor(context),
                border: Border(
                  top: BorderSide(
                    color: AppTheme.textMuted.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppTheme.textMuted),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        AppStrings.of(context)?.updateLater ?? 'Update later',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        AppStrings.of(context)?.updateNow ?? 'Update now',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatReleaseNotes(String notes) {
    if (notes.isEmpty) {
      // Can't access context here directly, use a default
      return 'No release notes';
    }

    // 简单的Markdown格式化
    String formatted = notes;

    // 移除多余的空行
    formatted = formatted.replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n');

    // 处理列表项
    formatted = formatted.replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '• ');

    // 处理标题
    formatted = formatted.replaceAll(RegExp(r'^\s*#+\s+(.+)$', multiLine: true), '\\1');

    return formatted.trim();
  }
}
