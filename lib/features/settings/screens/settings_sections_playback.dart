import 'package:material_ui/material_ui.dart';

import '../../../core/platform/platform_detector.dart';
import '../../../core/i18n/app_strings.dart';
import '../providers/settings_provider.dart';
import '../widgets/collapsible_settings_section.dart';
import '../widgets/settings_dialog_helpers.dart';
import '../widgets/settings_tiles.dart';
import '../widgets/settings_dialogs.dart';
import '../widgets/settings_playback_labels.dart';

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
