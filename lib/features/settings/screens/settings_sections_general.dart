import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/local_server_service.dart';
import '../providers/settings_provider.dart';
import '../providers/dlna_provider.dart';
import '../widgets/collapsible_settings_section.dart';
import '../widgets/settings_dialog_helpers.dart';
import '../widgets/settings_tiles.dart';
import '../widgets/settings_dialogs.dart';
import '../../epg/providers/epg_provider.dart';
import '../../../core/database/database_helper.dart';
import '../../backup/screens/backup_screen.dart';
import 'settings_sections_misc.dart';
  Widget buildStorageSection(
    BuildContext context,
    SettingsProvider settings,
  ) {
    return CollapsibleSettingsSection(
      title: AppStrings.of(context)?.storageCache ?? 'Storage & Cache',
      icon: Icons.storage_rounded,
      initiallyExpanded: false,
      children: [
        buildSwitchTile(
          context,
          title: AppStrings.of(context)?.logoCache ?? 'Logo Image Cache',
          subtitle: AppStrings.of(context)?.logoCacheDesc ??
              'Cache channel logos on disk to reduce data usage and speed up loading',
          icon: Icons.image_rounded,
          value: settings.logoCacheEnabled,
          onChanged: (value) async {
            await settings.setLogoCacheEnabled(value);
            final strings = AppStrings.of(context);
            showSuccess(
              context,
              value
                  ? (strings?.logoCacheEnabled ?? 'Logo cache enabled')
                  : (strings?.logoCacheDisabled ?? 'Logo cache disabled'),
            );
          },
        ),
        if (settings.logoCacheEnabled) ...[
          buildDivider(),
          buildSelectTile(
            context,
            title: AppStrings.of(context)?.logoCacheDays ?? 'Cache Retention',
            subtitle: logoCacheDaysLabel(context, settings.logoCacheDays),
            icon: Icons.schedule_rounded,
            onTap: () => showLogoCacheDaysDialog(context, settings),
          ),
          buildDivider(),
          buildSelectTile(
            context,
            title: AppStrings.of(context)?.logoCacheMaxObjects ??
                'Max Cache Items',
            subtitle:
                logoCacheMaxObjectsLabel(context, settings.logoCacheMaxObjects),
            icon: Icons.inventory_2_rounded,
            onTap: () => showLogoCacheMaxObjectsDialog(context, settings),
          ),
        ],
        buildDivider(),
        const LogoCacheInfoTile(),
        buildDivider(),
        buildActionTile(
          context,
          title: AppStrings.of(context)?.clearLogoCache ?? 'Clear Logo Cache',
          subtitle: AppStrings.of(context)?.clearLogoCacheDesc ??
              'Delete all cached logo images from disk',
          icon: Icons.delete_sweep_rounded,
          isDestructive: true,
          onTap: () async => await clearLogoCacheAction(context),
        ),
      ],
    );
  }

  /// 播放列表设置区块
  Widget buildPlaylistSection(
    BuildContext context,
    SettingsProvider settings,
  ) {
    return CollapsibleSettingsSection(
      title: AppStrings.of(context)?.playlists ?? 'Playlists',
      icon: Icons.playlist_play_rounded,
      initiallyExpanded: false,
      children: [
        buildSwitchTile(
          context,
          title: AppStrings.of(context)?.autoRefresh ?? 'Auto-refresh',
          subtitle: AppStrings.of(context)?.autoRefreshSubtitle ??
              'Automatically update playlists periodically',
          icon: Icons.refresh_rounded,
          value: settings.autoRefresh,
          onChanged: (value) {
            settings.setAutoRefresh(value);
            showSuccess(context,
                value ? 'Auto-refresh enabled' : 'Auto-refresh disabled');
          },
        ),
        if (settings.autoRefresh) ...[
          buildDivider(),
          buildSelectTile(
            context,
            title:
                AppStrings.of(context)?.refreshInterval ?? 'Refresh Interval',
            subtitle:
                'Every ${settings.refreshInterval} ${AppStrings.of(context)?.hours ?? 'hours'}',
            icon: Icons.schedule_rounded,
            onTap: () => showRefreshIntervalDialog(context, settings),
          ),
        ],
        buildDivider(),
        buildSwitchTile(
          context,
          title: AppStrings.of(context)?.rememberLastChannel ??
              'Remember Last Channel',
          subtitle: AppStrings.of(context)?.rememberLastChannelSubtitle ??
              'Resume playback from last watched channel',
          icon: Icons.history_rounded,
          value: settings.rememberLastChannel,
          onChanged: (value) {
            settings.setRememberLastChannel(value);
            final strings = AppStrings.of(context);
            showSuccess(
                context,
                value
                    ? (strings?.rememberLastChannelEnabled ??
                        'Remember last channel enabled')
                    : (strings?.rememberLastChannelDisabled ??
                        'Remember last channel disabled'));
          },
        ),
      ],
    );
  }

  /// General Settings区块
  Widget buildGeneralSection(
    BuildContext context,
    SettingsProvider settings,
  ) {
    return CollapsibleSettingsSection(
      title: AppStrings.of(context)?.general ?? 'General',
      icon: Icons.settings_rounded,
      initiallyExpanded: false,
      children: [
        buildSelectTile(
          context,
          title: AppStrings.of(context)?.language ?? 'Language',
          subtitle: currentLanguageLabel(context, settings),
          icon: Icons.language_rounded,
          onTap: () => showLanguageDialog(context, settings),
        ),
        buildDivider(),
        buildSelectTile(
          context,
          title: AppStrings.of(context)?.theme ?? 'Theme',
          subtitle: themeModeLabel(context, settings.themeMode),
          icon: Icons.palette_rounded,
          onTap: () => showThemeModeDialog(context, settings),
        ),
        buildDivider(),
        buildSelectTile(
          context,
          title: AppStrings.of(context)?.colorScheme ?? 'Color Scheme',
          subtitle: currentColorSchemeName(context, settings),
          icon: Icons.color_lens_rounded,
          onTap: () => showColorSchemeDialog(context),
        ),
        buildDivider(),
        buildSelectTile(
          context,
          title: AppStrings.of(context)?.fontFamily ?? '字体',
          subtitle: fontFamilyLabel(context, settings.fontFamily, settings),
          icon: Icons.text_fields_rounded,
          onTap: () => showFontFamilyDialog(context, settings),
        ),
        buildDivider(),
        buildSelectTile(
          context,
          title: AppStrings.of(context)?.homeFontSize ?? '首页字体大小',
          subtitle: homeFontSizeLabel(context, settings),
          icon: Icons.format_size_rounded,
          onTap: () => showHomeFontSizeDialog(context, settings),
        ),
        buildDivider(),
        buildSwitchTile(
          context,
          title: AppStrings.of(context)?.simpleMenu ?? 'Simple Menu',
          subtitle: AppStrings.of(context)?.simpleMenuSubtitle ??
              'Keep menu collapsed (no auto-expand)',
          icon: Icons.menu_rounded,
          value: settings.simpleMenu,
          onChanged: (value) {
            settings.setSimpleMenu(value);
            final strings = AppStrings.of(context);
            showSuccess(
                context,
                value
                    ? (strings?.simpleMenuEnabled ?? 'Simple menu enabled')
                    : (strings?.simpleMenuDisabled ?? 'Simple menu disabled'));
          },
        ),
        buildDivider(),
        buildSelectTile(
          context,
          title: AppStrings.of(context)?.pageTransitionAnimation ??
              'Page Transition Animation',
          subtitle:
              pageTransitionLabel(context, settings.pageTransitionAnimation),
          icon: Icons.animation_rounded,
          onTap: () => showPageTransitionDialog(context, settings),
        ),
        buildDivider(),
        buildSwitchTile(
          context,
          title: AppStrings.of(context)?.showWatchHistoryOnHome ??
              'Show Watch History on Home',
          subtitle: AppStrings.of(context)?.showWatchHistoryOnHomeSubtitle ??
              'Display recently watched channels on home screen',
          icon: Icons.history_rounded,
          value: settings.showWatchHistoryOnHome,
          onChanged: (value) {
            settings.setShowWatchHistoryOnHome(value);
            final strings = AppStrings.of(context);
            showSuccess(
                context,
                value
                    ? (strings?.watchHistoryOnHomeEnabled ??
                        'Watch history on home enabled')
                    : (strings?.watchHistoryOnHomeDisabled ??
                        'Watch history on home disabled'));
          },
        ),
        buildDivider(),
        buildSwitchTile(
          context,
          title: AppStrings.of(context)?.showFavoritesOnHome ??
              'Show Favorites on Home',
          subtitle: AppStrings.of(context)?.showFavoritesOnHomeSubtitle ??
              'Display favorite channels on home screen',
          icon: Icons.favorite_rounded,
          value: settings.showFavoritesOnHome,
          onChanged: (value) {
            settings.setShowFavoritesOnHome(value);
            final strings = AppStrings.of(context);
            showSuccess(
                context,
                value
                    ? (strings?.favoritesOnHomeEnabled ??
                        'Favorites on home enabled')
                    : (strings?.favoritesOnHomeDisabled ??
                        'Favorites on home disabled'));
          },
        ),
        buildDivider(),
        buildSwitchTile(
          context,
          title: AppStrings.of(context)?.channelSnapshotPreview ??
              'Channel Snapshot Preview',
          subtitle: AppStrings.of(context)?.channelSnapshotPreviewSubtitle ??
              'Show live snapshot when hovering a channel (requires rtp2httpd video-snapshot)',
          icon: Icons.videocam_rounded,
          value: settings.channelSnapshotPreview,
          onChanged: (value) {
            settings.setChannelSnapshotPreview(value);
            final strings = AppStrings.of(context);
            showSuccess(
                context,
                value
                    ? (strings?.channelSnapshotPreviewEnabled ??
                        'Channel snapshot preview enabled')
                    : (strings?.channelSnapshotPreviewDisabled ??
                        'Channel snapshot preview disabled'));
          },
        ),
      ],
    );
  }

  /// EPG Settings区块
  Widget buildEpgSection(
    BuildContext context,
    SettingsProvider settings,
  ) {
    return CollapsibleSettingsSection(
      title: AppStrings.of(context)?.epg ?? 'EPG (Electronic Program Guide)',
      icon: Icons.event_note_rounded,
      initiallyExpanded: false,
      children: [
        buildSwitchTile(
          context,
          title: AppStrings.of(context)?.enableEpg ?? 'Enable EPG',
          subtitle: AppStrings.of(context)?.enableEpgSubtitle ??
              'Show program information for channels',
          icon: Icons.event_note_rounded,
          value: settings.enableEpg,
          onChanged: (value) async {
            await settings.setEnableEpg(value);
            final strings = AppStrings.of(context);
            if (value) {
              // 启用 EPG 时，如果有配置 URL 则加载
              if (settings.epgUrl != null && settings.epgUrl!.isNotEmpty) {
                final success =
                    await context.read<EpgProvider>().loadEpg(settings.epgUrl!);
                if (success) {
                  showSuccess(
                      context,
                      strings?.epgEnabledAndLoaded ??
                          'EPG enabled and loaded successfully');
                } else {
                  // 失败时在通用提示后追加 P1-9 透传的具体原因，便于用户排查
                  final reason = context.read<EpgProvider>().error;
                  showError(
                      context,
                      (strings?.epgEnabledButFailed ??
                              'EPG enabled but failed to load') +
                          (reason != null ? ': $reason' : ''));
                }
              } else {
                showSuccess(
                    context,
                    strings?.epgEnabledPleaseConfigure ??
                        'EPG enabled, please configure EPG URL');
              }
            } else {
              // 关闭 EPG 时清除已加载的数据
              context.read<EpgProvider>().clear();
              showSuccess(context, strings?.epgDisabled ?? 'EPG disabled');
            }
          },
        ),
        if (settings.enableEpg) ...[
          buildDivider(),
          buildInputTile(
            context,
            title: AppStrings.of(context)?.epgUrl ?? 'EPG URL',
            subtitle: settings.epgUrl ??
                (AppStrings.of(context)?.notConfigured ?? 'Not configured'),
            icon: Icons.link_rounded,
            onTap: () => showEpgUrlDialog(context, settings),
          ),
        ],
      ],
    );
  }

  /// DLNA Settings区块
  Widget buildDlnaSection(
    BuildContext context,
    SettingsProvider settings,
  ) {
    return CollapsibleSettingsSection(
      title: AppStrings.of(context)?.dlnaCasting ?? 'DLNA Casting',
      icon: Icons.cast_rounded,
      initiallyExpanded: false,
      children: [
        Consumer<DlnaProvider>(
          builder: (context, dlnaProvider, _) {
            final strings = AppStrings.of(context);
            return buildSwitchTile(
              context,
              title: strings?.enableDlnaService ?? 'Enable DLNA Service',
              subtitle: dlnaProvider.isRunning
                  ? (strings?.dlnaServiceStarted ?? 'Started: {deviceName}')
                      .replaceFirst('{deviceName}', dlnaProvider.deviceName)
                  : strings?.allowOtherDevicesToCast ??
                      'Allow other devices to cast to this device',
              icon: Icons.cast_rounded,
              value: dlnaProvider.isEnabled,
              onChanged: (value) async {
                final success = await dlnaProvider.setEnabled(value);
                if (success) {
                  showSuccess(
                      context,
                      value
                          ? (strings?.dlnaServiceStartedMsg ??
                              'DLNA service started')
                          : (strings?.dlnaServiceStoppedMsg ??
                              'DLNA service stopped'));
                } else {
                  showError(
                      context,
                      strings?.dlnaServiceStartFailed ??
                          'Failed to start DLNA service, please check network connection');
                }
              },
            );
          },
        ),
      ],
    );
  }

  /// Backup & Restore Section区块
  Widget buildBackupSection(
    BuildContext context,
    SettingsProvider settings,
  ) {
    return CollapsibleSettingsSection(
      title: AppStrings.of(context)?.backupAndRestore ?? '备份与恢复',
      icon: Icons.backup_rounded,
      initiallyExpanded: false,
      children: [
        buildActionTile(
          context,
          title: AppStrings.of(context)?.backupAndRestore ?? '备份与恢复',
          subtitle:
              AppStrings.of(context)?.backupAndRestoreSubtitle ?? '备份和恢复应用数据',
          icon: Icons.backup_rounded,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BackupScreen()),
            );
          },
        ),
        buildActionTile(
          context,
          title: '修复数据库',
          subtitle: '清理引用已删除频道的孤立收藏/观看记录',
          icon: Icons.auto_fix_high_rounded,
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const AlertDialog(
                content: Row(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('正在修复数据库…'),
                  ],
                ),
              ),
            );
            try {
              await DatabaseHelper().repairDatabase();
              if (context.mounted) Navigator.pop(context);
              messenger.showSnackBar(const SnackBar(
                content: Text('数据库修复完成'),
                backgroundColor: Colors.green,
              ));
            } catch (e) {
              if (context.mounted) Navigator.pop(context);
              messenger.showSnackBar(SnackBar(
                content: Text('修复失败: $e'),
                backgroundColor: Colors.red,
              ));
            }
          },
        ),
      ],
    );
  }

  /// Developer & Debug Settings区块
  Widget buildDeveloperSection(
    BuildContext context,
    SettingsProvider settings,
  ) {
    return CollapsibleSettingsSection(
      title: AppStrings.of(context)?.developerAndDebug ?? 'Developer & Debug',
      icon: Icons.bug_report_rounded,
      initiallyExpanded: false,
      children: [
        buildSwitchTile(
          context,
          title: AppStrings.of(context)?.webLogEnabledTitle ?? '网页日志',
          subtitle: settings.webLogEnabled
              ? (AppStrings.of(context)?.webLogEnabledSubtitleOn ??
                  '已启用，浏览器访问 ${LocalServerService().logsUrl}')
              : (AppStrings.of(context)?.webLogEnabledSubtitleOff ??
                  '开启后可通过浏览器实时查看日志'),
          icon: Icons.language_rounded,
          value: settings.webLogEnabled,
          onChanged: (value) async {
            await settings.setWebLogEnabled(value);
            if (value) {
              showSuccess(
                  context,
                  AppStrings.of(context)?.webLogEnabledMsg ??
                      '网页日志已开启: ${LocalServerService().logsUrl}');
            }
          },
        ),
        buildDivider(),
        buildSelectTile(
          context,
          title: AppStrings.of(context)?.logLevel ?? 'Log Level',
          subtitle: logLevelLabel(context, settings.logLevel),
          icon: Icons.bug_report_rounded,
          onTap: () => showLogLevelDialog(context, settings),
        ),
        buildDivider(),
        buildActionTile(
          context,
          title: AppStrings.of(context)?.exportLogs ?? 'Export Logs',
          subtitle: AppStrings.of(context)?.exportLogsSubtitle ??
              'Export log files for diagnostics',
          icon: Icons.file_download_rounded,
          onTap: () => exportLogs(context),
        ),
        buildDivider(),
        buildActionTile(
          context,
          title: AppStrings.of(context)?.clearLogs ?? 'Clear Logs',
          subtitle: AppStrings.of(context)?.clearLogsSubtitle ??
              'Delete all log files',
          icon: Icons.delete_sweep_rounded,
          onTap: () => clearLogs(context),
        ),
        if (settings.logLevel != 'off') ...[
          buildDivider(),
          buildActionTile(
            context,
            title:
                AppStrings.of(context)?.logFileLocation ?? 'Log File Location',
            subtitle: ServiceLocator.log.logFilePath ?? 'Unknown',
            icon: Icons.folder_rounded,
            onTap: () => openLogFolder(context),
          ),
        ],
      ],
    );
  }

  /// About Section区块
  Widget buildAboutSection(
    BuildContext context,
    SettingsProvider settings,
  ) {
    return CollapsibleSettingsSection(
      title: AppStrings.of(context)?.about ?? 'About',
      icon: Icons.info_outline_rounded,
      initiallyExpanded: false,
      children: [
        FutureBuilder<String>(
          future: getCurrentVersion(),
          builder: (context, snapshot) {
            return buildInfoTile(
              context,
              title: AppStrings.of(context)?.version ?? 'Version',
              value: snapshot.data ?? 'Loading...',
              icon: Icons.info_outline_rounded,
            );
          },
        ),
        buildDivider(),
        buildActionTile(
          context,
          title: AppStrings.of(context)?.checkUpdate ?? 'Check for Updates',
          subtitle: AppStrings.of(context)?.checkUpdateSubtitle ??
              'Check if a new version is available',
          icon: Icons.system_update_rounded,
          onTap: () => checkForUpdates(context),
        ),
        buildDivider(),
        buildInfoTile(
          context,
          title: AppStrings.of(context)?.platform ?? 'Platform',
          value: platformName(),
          icon: Icons.devices_rounded,
        ),
      ],
    );
  }

  /// Reset Section区块
  Widget buildResetSection(
    BuildContext context,
    SettingsProvider settings,
  ) {
    return CollapsibleSettingsSection(
      title: AppStrings.of(context)?.resetAllSettings ?? 'Reset All Settings',
      icon: Icons.restore_rounded,
      initiallyExpanded: false,
      children: [
        buildActionTile(
          context,
          title:
              AppStrings.of(context)?.resetAllSettings ?? 'Reset All Settings',
          subtitle: AppStrings.of(context)?.resetSettingsSubtitle ??
              'Restore all settings to default values',
          icon: Icons.restore_rounded,
          isDestructive: true,
          onTap: () => confirmResetSettings(context, settings),
        ),
      ],
    );
  }

