import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_sidebar.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/i18n/app_strings.dart';
import '../providers/settings_provider.dart';
import '../widgets/settings_dialogs.dart';
import 'settings_sections.dart';

class SettingsScreen extends StatefulWidget {
  final bool embedded;
  final bool autoCheckUpdate;

  const SettingsScreen(
      {super.key, this.embedded = false, this.autoCheckUpdate = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // 如果需要自动检查更新，延迟执行
    if (widget.autoCheckUpdate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        checkForUpdates(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTV = PlatformDetector.isTV || size.width > 1200;
    final isWindows = PlatformDetector.isWindows;
    final isAndroid = PlatformDetector.isAndroid;
    final isMobile = PlatformDetector.isMobile;

    final content = Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // General Settings
            buildGeneralSection(context, settings),

            // Playback Settings
            buildPlaybackSection(
              context,
              settings,
              isWindows: isWindows,
              isAndroid: isAndroid,
              isMobile: isMobile,
              isTV: isTV,
            ),

            // Storage & Cache Settings
            buildStorageSection(context, settings),

            // Playlist Settings
            buildPlaylistSection(context, settings),

            // EPG Settings
            buildEpgSection(context, settings),

            // DLNA Settings
            buildDlnaSection(context, settings),

            // Backup & Restore
            buildBackupSection(context, settings),

            // Developer & Debug
            buildDeveloperSection(context, settings),

            // About
            buildAboutSection(context, settings),

            // Reset
            buildResetSection(context, settings),

            const SizedBox(height: 40),
          ],
        );
      },
    );

    if (isTV) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: Theme.of(context).brightness == Brightness.dark
                  ? [
                      AppTheme.getBackgroundColor(context),
                      AppTheme.getPrimaryColor(context).withOpacity(0.15),
                      AppTheme.getBackgroundColor(context),
                    ]
                  : [
                      AppTheme.getBackgroundColor(context),
                      AppTheme.getBackgroundColor(context).withOpacity(0.9),
                      AppTheme.getPrimaryColor(context).withOpacity(0.08),
                    ],
            ),
          ),
          child: TVSidebar(
            selectedIndex: 5, // 设置页
            child: content,
          ),
        ),
      );
    }

    // 嵌入模式不使用Scaffold
    if (widget.embedded) {
      final isMobile = PlatformDetector.isMobile;
      final isLandscape = isMobile && MediaQuery.of(context).size.width > 700;
      final statusBarHeight =
          isMobile ? MediaQuery.of(context).padding.top : 0.0;
      final topPadding =
          isMobile ? (statusBarHeight > 0 ? statusBarHeight - 15.0 : 0.0) : 0.0;

      return Column(
        children: [
          // 简化的标题栏
          Container(
            padding: EdgeInsets.fromLTRB(
              12,
              topPadding + (isLandscape ? 4 : 8), // 使用和首页相同的topPadding
              12,
              isLandscape ? 4 : 8,
            ),
            child: Row(
              children: [
                Text(
                  AppStrings.of(context)?.settings ?? 'Settings',
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontSize: isLandscape ? 14 : 18, // 横屏时字体更小
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.getBackgroundColor(context),
              AppTheme.getBackgroundColor(context).withOpacity(0.8),
              AppTheme.getPrimaryColor(context).withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          children: [
            // 手机端添加状态栏高度
            if (PlatformDetector.isMobile)
              SizedBox(height: MediaQuery.of(context).padding.top),
            AppBar(
              backgroundColor: Colors.transparent,
              primary: false, // 禁用自动SafeArea padding
              toolbarHeight: PlatformDetector.isMobile &&
                      MediaQuery.of(context).size.width > 600
                  ? 24.0
                  : 56.0, // 横屏时减小到24px
              automaticallyImplyLeading: false, // 不显示返回按钮
              title: Text(
                AppStrings.of(context)?.settings ?? 'Settings',
                style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontSize: PlatformDetector.isMobile &&
                            MediaQuery.of(context).size.width > 600
                        ? 14
                        : 20, // 横屏时字体14px
                    fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

}
