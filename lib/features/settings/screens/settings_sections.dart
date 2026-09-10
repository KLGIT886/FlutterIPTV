import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/local_server_service.dart';
import '../providers/settings_provider.dart';
import '../providers/dlna_provider.dart';
import '../widgets/qr_log_export_dialog.dart';
import '../widgets/collapsible_settings_section.dart';
import '../widgets/settings_dialog_helpers.dart';
import '../widgets/settings_tiles.dart';
import '../widgets/settings_dialogs.dart';
import '../widgets/settings_playback_labels.dart';
import '../../epg/providers/epg_provider.dart';
import '../../../core/database/database_helper.dart';
import '../../backup/screens/backup_screen.dart';

  /// 播放设置区块（Windows 硬解 / Android 移动 / Android TV / 其他平台分支）
  Widget buildPlaybackSection(
    BuildContext context,
    SettingsProvider settings, {
    required bool isWindows,
    required bool isAndroid,
    required bool isMobile,
    required bool isTV,
  }) {
    return CollapsibleSettingsSection(
      title: AppStrings.of(context)?.playback ?? 'Playback',
      icon: Icons.play_circle_outline_rounded,
      initiallyExpanded: false,
      children: [
        buildSwitchTile(
          context,
          title: AppStrings.of(context)?.autoPlay ?? 'Auto-play',
          subtitle: AppStrings.of(context)?.autoPlaySubtitle ??
              'Automatically start playback when selecting a channel',
          icon: Icons.play_circle_outline_rounded,
          value: settings.autoPlay,
          onChanged: (value) {
            settings.setAutoPlay(value);
            final strings = AppStrings.of(context);
            showSuccess(
                context,
                value
                    ? (strings?.autoPlayEnabled ?? 'Auto-play enabled')
                    : (strings?.autoPlayDisabled ?? 'Auto-play disabled'));
          },
        ),
        if (isWindows) ...[
          buildDivider(),
          buildSelectTile(
            context,
            title: AppStrings.of(context)?.decodingMode ?? 'Decoding Mode',
            subtitle: getDecodingModeLabel(context, settings.decodingMode),
            icon: Icons.tune_rounded,
            onTap: () => showDecodingModeDialog(context, settings),
          ),
          buildDivider(),
          buildSelectTile(
            context,
            title: AppStrings.of(context)?.windowsHwdecMode ??
                'Windows HW Decoder',
            subtitle: getWindowsHwdecLabel(context, settings.windowsHwdecMode),
            icon: Icons.speed_rounded,
            onTap: () => showWindowsHwdecDialog(context, settings),
          ),
          // d3d11vpp 去交错参数：仅 auto-safe 方案下显示并生效
          if (settings.windowsHwdecMode == 'auto-safe') ...[
            buildDivider(),
            buildSelectTile(
              context,
              title: AppStrings.of(context)?.d3d11vppMode ??
                  'D3D11VPP Deinterlace',
              subtitle: AppStrings.of(context)?.d3d11vppModeDesc ??
                  'Only applies to Auto (Safe)',
              icon: Icons.layers_rounded,
              onTap: () => showD3d11vppDialog(context, settings),
            ),
          ],
          buildDivider(),
          buildSwitchTile(
            context,
            title: AppStrings.of(context)?.allowSoftwareFallback ??
                'Allow Software Fallback',
            subtitle: AppStrings.of(context)?.allowSoftwareFallbackDesc ??
                'If hardware decode fails, automatically switch to software decoding.',
            icon: Icons.swap_horiz_rounded,
            value: settings.allowSoftwareFallback,
            onChanged: (value) async {
              await settings.setAllowSoftwareFallback(value);
              await reinitMediaKitPlayer(context, settings);
              final strings = AppStrings.of(context);
              showSuccess(
                context,
                value
                    ? (strings?.allowSoftwareFallbackEnabled ??
                        'Software fallback enabled')
                    : (strings?.allowSoftwareFallbackDisabled ??
                        'Software fallback disabled'),
              );
            },
          ),
          buildDivider(),
          buildSelectTile(
            context,
            title: AppStrings.of(context)?.videoOutput ?? 'Video Output',
            subtitle: getVideoOutputLabel(context, settings.videoOutput),
            icon: Icons.display_settings_rounded,
            onTap: () => showVideoOutputDialog(context, settings),
          ),
          buildDivider(),
          buildSwitchTile(
            context,
            title: AppStrings.of(context)?.deinterlace ?? 'Deinterlace',
            subtitle: AppStrings.of(context)?.deinterlaceDesc ??
                'Apply deinterlacing filter for interlaced video (480i/576i/1080i)',
            icon: Icons.deblur_rounded,
            value: settings.deinterlaceEnabled,
            onChanged: (value) async {
              await settings.setDeinterlaceEnabled(value);
              await reinitMediaKitPlayer(context, settings);
              final strings = AppStrings.of(context);
              showSuccess(
                context,
                value
                    ? (strings?.deinterlaceEnabled ?? 'Deinterlace enabled')
                    : (strings?.deinterlaceDisabled ?? 'Deinterlace disabled'),
              );
            },
          ),
          if (settings.deinterlaceEnabled) ...[
            // 去交错模式下拉已移除：当前 mpv 构建不支持 vf 滤镜（yadif/bwdif 等），
            // 仅使用 deinterlace=yes/no 属性，无需选择模式
          ],
        ] else if (isAndroid && isMobile) ...[
          buildDivider(),
          buildSelectTile(
            context,
            title: AppStrings.of(context)?.decodingMode ?? 'Decoding Mode',
            subtitle: getDecodingModeLabel(context, settings.decodingMode),
            icon: Icons.tune_rounded,
            onTap: () => showDecodingModeDialog(context, settings,
                options: const ['auto', 'hardware', 'software']),
          ),
          buildDivider(),
          buildSwitchTile(
            context,
            title: AppStrings.of(context)?.allowSoftwareFallback ??
                'Allow Software Fallback',
            subtitle: AppStrings.of(context)?.allowSoftwareFallbackDesc ??
                'If hardware decode fails, automatically switch to software decoding.',
            icon: Icons.swap_horiz_rounded,
            value: settings.allowSoftwareFallback,
            onChanged: (value) async {
              await settings.setAllowSoftwareFallback(value);
              await reinitMediaKitPlayer(context, settings);
              final strings = AppStrings.of(context);
              showSuccess(
                context,
                value
                    ? (strings?.allowSoftwareFallbackEnabled ??
                        'Software fallback enabled')
                    : (strings?.allowSoftwareFallbackDisabled ??
                        'Software fallback disabled'),
              );
            },
          ),
          buildDivider(),
          buildSelectTile(
            context,
            title: AppStrings.of(context)?.videoOutput ?? 'Video Output',
            subtitle: getVideoOutputLabel(context, settings.videoOutput),
            icon: Icons.display_settings_rounded,
            onTap: () => showVideoOutputDialog(
              context,
              settings,
              options: const ['auto', 'libmpv'],
            ),
          ),
        ] else if (isAndroid && isTV) ...[
          buildDivider(),
          buildSelectTile(
            context,
            title: AppStrings.of(context)?.decodingMode ?? 'Decoding Mode',
            subtitle: getDecodingModeLabel(context, settings.decodingMode),
            icon: Icons.tune_rounded,
            onTap: () => showDecodingModeDialog(
              context,
              settings,
              options: const ['auto', 'software'],
            ),
          ),
          buildDivider(),
          buildSwitchTile(
            context,
            title: AppStrings.of(context)?.allowSoftwareFallback ??
                'Allow Software Fallback',
            subtitle: AppStrings.of(context)?.allowSoftwareFallbackDesc ??
                'If hardware decode fails, automatically switch to software decoding.',
            icon: Icons.swap_horiz_rounded,
            value: settings.allowSoftwareFallback,
            onChanged: (value) async {
              await settings.setAllowSoftwareFallback(value);
              await reinitMediaKitPlayer(context, settings);
              final strings = AppStrings.of(context);
              showSuccess(
                context,
                value
                    ? (strings?.allowSoftwareFallbackEnabled ??
                        'Software fallback enabled')
                    : (strings?.allowSoftwareFallbackDisabled ??
                        'Software fallback disabled'),
              );
            },
          ),
        ] else ...[
          buildDivider(),
          buildSwitchTile(
            context,
            title: AppStrings.of(context)?.allowSoftwareFallback ??
                'Allow Software Fallback',
            subtitle: AppStrings.of(context)?.allowSoftwareFallbackDesc ??
                'If hardware decode fails, automatically switch to software decoding.',
            icon: Icons.swap_horiz_rounded,
            value: settings.allowSoftwareFallback,
            onChanged: (value) async {
              await settings.setAllowSoftwareFallback(value);
              await reinitMediaKitPlayer(context, settings);
              final strings = AppStrings.of(context);
              showSuccess(
                context,
                value
                    ? (strings?.allowSoftwareFallbackEnabled ??
                        'Software fallback enabled')
                    : (strings?.allowSoftwareFallbackDisabled ??
                        'Software fallback disabled'),
              );
            },
          ),
          buildDivider(),
          buildSelectTile(
            context,
            title: AppStrings.of(context)?.videoOutput ?? 'Video Output',
            subtitle: getVideoOutputLabel(context, settings.videoOutput),
            icon: Icons.display_settings_rounded,
            onTap: () => showVideoOutputDialog(context, settings),
          ),
        ],
        buildDivider(),
        buildSelectTile(
          context,
          title:
              AppStrings.of(context)?.channelMergeRule ?? 'Channel Merge Rule',
          subtitle: channelMergeRuleLabel(context, settings.channelMergeRule),
          icon: Icons.merge_rounded,
          onTap: () => showChannelMergeRuleDialog(context, settings),
        ),
        // 缓冲大小 - 暂时隐藏（未实现）
        // buildDivider(),
        // buildSelectTile(
        //   context,
        //   title: AppStrings.of(context)?.bufferSize ?? 'Buffer Size',
        //   subtitle: '${settings.bufferSize} ${AppStrings.of(context)?.seconds ?? 'seconds'} ${AppStrings.of(context)?.notImplemented ?? '(Not implemented)'}',
        //   icon: Icons.storage_rounded,
        //   onTap: () => _showBufferSizeDialog(context, settings),
        // ),
        buildDivider(),
        buildSelectTile(
          context,
          title: AppStrings.of(context)?.bufferStrength ?? 'Buffer Strength',
          subtitle: bufferStrengthLabel(context, settings.bufferStrength),
          icon: Icons.speed_rounded,
          onTap: () => showBufferStrengthDialog(context, settings),
        ),
        buildDivider(),
        buildSelectTile(
          context,
          title: AppStrings.of(context)?.userAgent ?? 'User-Agent',
          subtitle: userAgentLabel(context, settings.userAgent),
          icon: Icons.public_rounded,
          onTap: () => showUserAgentDialog(context),
        ),
        buildDivider(),
        buildSwitchTile(
          context,
          title: AppStrings.of(context)?.showUserAgent ?? 'Show User-Agent',
          subtitle: AppStrings.of(context)?.showUserAgentSubtitle ??
              'Display User-Agent in player OSD',
          icon: Icons.info_outline_rounded,
          value: settings.showUserAgent,
          onChanged: (value) {
            settings.setShowUserAgent(value);
            final strings = AppStrings.of(context);
            showSuccess(
                context,
                value
                    ? (strings?.userAgentDisplayEnabled ??
                        'User-Agent display enabled')
                    : (strings?.userAgentDisplayDisabled ??
                        'User-Agent display disabled'));
          },
        ),
        buildDivider(),
        buildSwitchTile(
          context,
          title: AppStrings.of(context)?.showFps ?? 'Show FPS',
          subtitle: AppStrings.of(context)?.showFpsSubtitle ??
              'Show frame rate in top-right corner of player',
          icon: Icons.speed_rounded,
          value: settings.showFps,
          onChanged: (value) {
            settings.setShowFps(value);
            final strings = AppStrings.of(context);
            showSuccess(
                context,
                value
                    ? (strings?.fpsEnabled ?? 'FPS display enabled')
                    : (strings?.fpsDisabled ?? 'FPS display disabled'));
          },
        ),
        buildDivider(),
        buildSwitchTile(
          context,
          title: AppStrings.of(context)?.showClock ?? 'Show Clock',
          subtitle: AppStrings.of(context)?.showClockSubtitle ??
              'Show current time in top-right corner of player',
          icon: Icons.schedule_rounded,
          value: settings.showClock,
          onChanged: (value) {
            settings.setShowClock(value);
            final strings = AppStrings.of(context);
            showSuccess(
                context,
                value
                    ? (strings?.clockEnabled ?? 'Clock display enabled')
                    : (strings?.clockDisabled ?? 'Clock display disabled'));
          },
        ),
        buildDivider(),
        buildSwitchTile(
          context,
          title:
              AppStrings.of(context)?.showNetworkSpeed ?? 'Show Network Speed',
          subtitle: AppStrings.of(context)?.showNetworkSpeedSubtitle ??
              'Show download speed in top-right corner of player',
          icon: Icons.network_check_rounded,
          value: settings.showNetworkSpeed,
          onChanged: (value) {
            settings.setShowNetworkSpeed(value);
            final strings = AppStrings.of(context);
            showSuccess(
                context,
                value
                    ? (strings?.networkSpeedEnabled ??
                        'Network speed display enabled')
                    : (strings?.networkSpeedDisabled ??
                        'Network speed display disabled'));
          },
        ),
        buildDivider(),
        buildSwitchTile(
          context,
          title: AppStrings.of(context)?.showVideoInfo ?? 'Show Resolution',
          subtitle: AppStrings.of(context)?.showVideoInfoSubtitle ??
              'Show video resolution and bitrate in top-right corner',
          icon: Icons.high_quality_rounded,
          value: settings.showVideoInfo,
          onChanged: (value) {
            settings.setShowVideoInfo(value);
            final strings = AppStrings.of(context);
            showSuccess(
                context,
                value
                    ? (strings?.videoInfoEnabled ??
                        'Resolution display enabled')
                    : (strings?.videoInfoDisabled ??
                        'Resolution display disabled'));
          },
        ),
        buildDivider(),
        buildSelectTile(
          context,
          title: AppStrings.of(context)?.progressBarMode ?? '进度条显示',
          subtitle: progressBarModeLabel(context, settings.progressBarMode),
          icon: Icons.linear_scale_rounded,
          onTap: () => showProgressBarModeDialog(context, settings),
        ),
        if (PlatformDetector.isTV) ...[
          buildDivider(),
          buildSelectTile(
            context,
            title: AppStrings.of(context)?.seekStepSeconds ?? '快进/快退跨度',
            subtitle: seekStepLabel(context, settings.seekStepSeconds),
            icon: Icons.fast_forward_rounded,
            onTap: () => showSeekStepDialog(context, settings),
          ),
        ],
        if (PlatformDetector.isDesktop || PlatformDetector.isTV) ...[
          buildDivider(),
          buildSwitchTile(
            context,
            title: AppStrings.of(context)?.enableMultiScreen ??
                'Multi-Screen Mode',
            subtitle: AppStrings.of(context)?.enableMultiScreenSubtitle ??
                'Enable 2x2 split screen for simultaneous viewing',
            icon: Icons.view_quilt_rounded,
            value: settings.enableMultiScreen,
            onChanged: (value) {
              settings.setEnableMultiScreen(value);
              final strings = AppStrings.of(context);
              showSuccess(
                  context,
                  value
                      ? (strings?.multiScreenEnabled ??
                          'Multi-screen mode enabled')
                      : (strings?.multiScreenDisabled ??
                          'Multi-screen mode disabled'));
            },
          ),
          if (settings.enableMultiScreen && PlatformDetector.isDesktop) ...[
            buildDivider(),
            buildSelectTile(
              context,
              title: AppStrings.of(context)?.defaultScreenPosition ??
                  'Default Screen Position',
              subtitle:
                  screenPositionLabel(context, settings.defaultScreenPosition),
              icon: Icons.crop_free_rounded,
              onTap: () => showScreenPositionDialog(context, settings),
            ),
          ],
          buildDivider(),
          buildSwitchTile(
            context,
            title: AppStrings.of(context)?.showMultiScreenChannelName ??
                'Show Channel Names',
            subtitle:
                AppStrings.of(context)?.showMultiScreenChannelNameSubtitle ??
                    'Display channel names in multi-screen playback',
            icon: Icons.text_fields_rounded,
            value: settings.showMultiScreenChannelName,
            onChanged: (value) {
              settings.setShowMultiScreenChannelName(value);
              final strings = AppStrings.of(context);
              showSuccess(
                  context,
                  value
                      ? (strings?.multiScreenChannelNameEnabled ??
                          'Multi-screen channel name display enabled')
                      : (strings?.multiScreenChannelNameDisabled ??
                          'Multi-screen channel name display disabled'));
            },
          ),
        ],
        // 手机端屏幕方向设置
        if (PlatformDetector.isMobile) ...[
          buildDivider(),
          buildSelectTile(
            context,
            title: '屏幕方向',
            subtitle: orientationLabel(context, settings.mobileOrientation),
            icon: Icons.screen_rotation_rounded,
            onTap: () => showOrientationDialog(context, settings),
          ),
        ],
        // 音量标准化 - 暂时隐藏（未实现）
        // buildDivider(),
        // buildSwitchTile(
        //   context,
        //   title: AppStrings.of(context)?.volumeNormalization ?? 'Volume Normalization',
        //   subtitle: '${AppStrings.of(context)?.volumeNormalizationSubtitle ?? 'Auto-adjust volume differences between channels'} ${AppStrings.of(context)?.notImplemented ?? '(Not implemented)'}',
        //   icon: Icons.volume_up_rounded,
        //   value: settings.volumeNormalization,
        //   onChanged: (value) {
        //     settings.setVolumeNormalization(value);
        //     final strings = AppStrings.of(context);
        //     showError(context, strings?.volumeNormalizationNotImplemented ?? 'Volume normalization not implemented, setting will not take effect');
        //   },
        // ),
        // 音量增强 - 始终显示（已实现）
        buildDivider(),
        buildSelectTile(
          context,
          title: AppStrings.of(context)?.volumeBoost ?? 'Volume Boost',
          subtitle: settings.volumeBoost == 0
              ? (AppStrings.of(context)?.noBoost ?? 'No boost')
              : '${settings.volumeBoost > 0 ? '+' : ''}${settings.volumeBoost} dB',
          icon: Icons.equalizer_rounded,
          onTap: () => showVolumeBoostDialog(context, settings),
        ),
      ],
    );
  }

  /// 存储与缓存设置区块
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
