import 'package:flutter/material.dart';
import '../models/app_update.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';

class UpdateManager {
  static final UpdateManager _instance = UpdateManager._internal();
  factory UpdateManager() => _instance;
  UpdateManager._internal();

  final UpdateService _updateService = UpdateService();

  /// 检查更新并显示更新对话框
  Future<void> checkAndShowUpdateDialog(BuildContext context, {bool forceCheck = false}) async {
    try {
      debugPrint('UPDATE_MANAGER: 开始检查更新...');

      final update = await _updateService.checkForUpdates(forceCheck: forceCheck);

      if (update != null && context.mounted) {
        debugPrint('UPDATE_MANAGER: 发现新版本，显示更新对话框');
        _showUpdateDialog(context, update);
      } else {
        debugPrint('UPDATE_MANAGER: 没有发现新版本');
      }
    } catch (e) {
      debugPrint('UPDATE_MANAGER: 检查更新时发生错误: $e');
    }
  }

  /// 手动检查更新
  Future<void> manualCheckForUpdate(BuildContext context) async {
    try {
      debugPrint('UPDATE_MANAGER: 手动检查更新...');

      // 显示加载提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('正在检查更新...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      final update = await _updateService.checkForUpdates(forceCheck: true);

      // 隐藏加载提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (update != null && context.mounted) {
        debugPrint('UPDATE_MANAGER: 发现新版本，显示更新对话框');
        _showUpdateDialog(context, update);
      } else if (context.mounted) {
        debugPrint('UPDATE_MANAGER: 已是最新版本');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已是最新版本'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('UPDATE_MANAGER: 手动检查更新时发生错误: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('检查更新失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 显示更新对话框
  void _showUpdateDialog(BuildContext context, AppUpdate update) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateDialog(
        update: update,
        onUpdate: () => _handleUpdate(context, update),
        onCancel: () {
          Navigator.of(context).pop();
          debugPrint('UPDATE_MANAGER: 用户选择稍后更新');
        },
      ),
    );
  }

  /// 处理更新操作
  Future<void> _handleUpdate(BuildContext context, AppUpdate update) async {
    try {
      debugPrint('UPDATE_MANAGER: 用户选择立即更新');

      // 关闭对话框
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // 打开下载页面
      final success = await _updateService.openDownloadPage();

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已打开下载页面'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('无法打开下载页面，请手动访问GitHub'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('UPDATE_MANAGER: 处理更新时发生错误: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 获取当前应用版本
  Future<String> getCurrentVersion() async {
    try {
      return await _updateService.getCurrentVersion();
    } catch (e) {
      debugPrint('UPDATE_MANAGER: 获取当前版本失败: $e');
      return '0.0.0';
    }
  }
}
