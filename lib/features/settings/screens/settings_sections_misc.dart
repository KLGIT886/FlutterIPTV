import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/services/service_locator.dart';
import '../widgets/qr_log_export_dialog.dart';
import '../widgets/settings_dialogs.dart';
  Future<void> exportLogs(BuildContext context) async {
    // 显示二维码对话框
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const QrLogExportDialog(),
    );
  }

  Future<void> clearLogs(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(context),
        title: Text(
          AppStrings.of(context)?.clearLogsConfirm ?? 'Clear Logs',
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
        ),
        content: Text(
          AppStrings.of(context)?.clearLogsConfirmMessage ??
              'Are you sure you want to delete all log files? This action cannot be undone.',
          style: TextStyle(color: AppTheme.getTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.of(context)?.cancel ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppStrings.of(context)?.delete ?? 'Delete',
              style: const TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ServiceLocator.log.clearLogs();
        if (context.mounted) {
          showSuccess(
              context, AppStrings.of(context)?.logsCleared ?? 'Logs cleared');
        }
      } catch (e) {
        if (context.mounted) {
          showError(context, '${AppStrings.of(context)?.error ?? "Error"}: $e');
        }
      }
    }
  }

  Future<void> openLogFolder(BuildContext context) async {
    try {
      final logPath = ServiceLocator.log.logFilePath;
      if (logPath == null) {
        showError(context, 'Log file path not available');
        return;
      }

      // 获取日志文件所在的目录
      final logDir =
          logPath.substring(0, logPath.lastIndexOf(Platform.pathSeparator));

      if (Platform.isWindows) {
        // Windows: 使用 explorer 打开文件夹
        await Process.run('explorer', [logDir]);
      } else if (Platform.isMacOS) {
        // macOS: 使用 open 命令
        await Process.run('open', [logDir]);
      } else if (Platform.isLinux) {
        // Linux: 使用 xdg-open 命令
        await Process.run('xdg-open', [logDir]);
      } else {
        showError(context, 'Opening folders is not supported on this platform');
      }
    } catch (e) {
      if (context.mounted) {
        showError(context, 'Failed to open folder: $e');
      }
    }
  }

  // 获取当前应用版本
  Future<String> getCurrentVersion() async {
    try {
      return await ServiceLocator.updateService.getCurrentVersion();
    } catch (e) {
      return '1.1.11'; // 默认版本
    }
  }
/// Widget: 显示台标缓存当前使用情况（大小 + 数量）
/// 支持点击刷新
class LogoCacheInfoTile extends StatefulWidget {
  const LogoCacheInfoTile({super.key});

  @override
  State<LogoCacheInfoTile> createState() => LogoCacheInfoTileState();
}

class LogoCacheInfoTileState extends State<LogoCacheInfoTile> {
  String _size = '--';
  String _count = '--';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      // 诊断：记录缓存目录路径
      await ServiceLocator.logoCache.logCachePaths();
      final sizeFuture = ServiceLocator.logoCache.getCacheSizeFormatted();
      final countFuture = ServiceLocator.logoCache.getCacheObjectCount();
      final results = await Future.wait<Object>([sizeFuture, countFuture]);
      if (!mounted) return;
      setState(() {
        _size = results[0] as String;
        _count = '${results[1]}';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _size = 'Err';
        _count = '?';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = PlatformDetector.isMobile;
    final isLandscape = isMobile && MediaQuery.of(context).size.width > 600;
    final strings = AppStrings.of(context);

    return TVFocusable(
      onSelect: _refresh,
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
        onTap: _refresh,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 12 : 16,
            vertical: isLandscape ? 8 : 14,
          ),
          child: Row(
            children: [
              Icon(
                _loading
                    ? Icons.hourglass_empty_rounded
                    : Icons.data_saver_on_rounded,
                color: AppTheme.getPrimaryColor(context),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings?.logoCacheUsage ?? 'Cache Usage',
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontSize: isLandscape ? 13 : 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _loading
                        ? Text(
                            strings?.calculating ?? 'Calculating...',
                            style: TextStyle(
                              color: AppTheme.getTextMuted(context),
                              fontSize: isLandscape ? 10 : 12,
                            ),
                          )
                        : Text(
                            '${strings?.size ?? 'Size'}: $_size  ·  ${strings?.items ?? 'Items'}: $_count',
                            style: TextStyle(
                              color: AppTheme.getTextMuted(context),
                              fontSize: isLandscape ? 10 : 12,
                            ),
                          ),
                  ],
                ),
              ),
              Icon(
                Icons.refresh_rounded,
                color: AppTheme.getTextMuted(context),
                size: isLandscape ? 18 : 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
