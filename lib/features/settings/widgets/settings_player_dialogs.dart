import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/color_scheme_dialog.dart';
import '../../../core/i18n/app_strings.dart';
import '../widgets/user_agent_dialog.dart';
import '../widgets/settings_dialog_helpers.dart';
import '../widgets/settings_playback_labels.dart';
import '../../player/providers/player_provider.dart';
import '../../multi_screen/providers/multi_screen_provider.dart';
import '../providers/settings_provider.dart';

import 'settings_feedback.dart';

void showColorSchemeDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const ColorSchemeDialog(),
  );
}

void showDecodingModeDialog(
  BuildContext context,
  SettingsProvider settings, {
  List<String>? options,
}) {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;
  final isLandscape =
      screenWidth > 600 && screenWidth < 900 && screenHeight < screenWidth;
  final modeOptions = options ?? const ['auto', 'hardware', 'software'];

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(dialogContext),
        contentPadding: EdgeInsets.fromLTRB(
          isLandscape ? 16 : 24,
          isLandscape ? 8 : 16,
          isLandscape ? 16 : 24,
          isLandscape ? 8 : 16,
        ),
        title: Text(
          AppStrings.of(context)?.decodingMode ?? 'Decoding Mode',
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontSize: isLandscape ? 14 : 18,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: modeOptions.map((mode) {
              return RadioListTile<String>(
                title: Text(
                  getDecodingModeLabel(context, mode),
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontSize: isLandscape ? 12 : 14,
                  ),
                ),
                subtitle: Text(
                  getDecodingModeDesc(context, mode),
                  style: TextStyle(
                    color: AppTheme.getTextMuted(context),
                    fontSize: isLandscape ? 9 : 11,
                  ),
                ),
                value: mode,
                groupValue: settings.decodingMode,
                onChanged: (value) async {
                  if (value != null) {
                    await settings.setDecodingMode(value);
                    await reinitMediaKitPlayer(context, settings);
                    Navigator.pop(dialogContext);
                    final strings = AppStrings.of(context);
                    showSuccess(
                      context,
                      (strings?.decodingModeSet ??
                              'Decoding mode set to: {mode}')
                          .replaceFirst(
                              '{mode}', getDecodingModeLabel(context, value)),
                    );
                  }
                },
                activeColor: AppTheme.getPrimaryColor(dialogContext),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 8 : 16,
                  vertical: isLandscape ? 0 : 4,
                ),
              );
            }).toList(),
          ),
        ),
      );
    },
  );
}

void showVideoOutputDialog(
  BuildContext context,
  SettingsProvider settings, {
  List<String>? options,
}) {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;
  final isLandscape =
      screenWidth > 600 && screenWidth < 900 && screenHeight < screenWidth;
  final outputOptions = options ?? const ['auto', 'libmpv', 'gpu'];

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(dialogContext),
        contentPadding: EdgeInsets.fromLTRB(
          isLandscape ? 16 : 24,
          isLandscape ? 8 : 16,
          isLandscape ? 16 : 24,
          isLandscape ? 8 : 16,
        ),
        title: Text(
          AppStrings.of(context)?.videoOutput ?? 'Video Output',
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontSize: isLandscape ? 14 : 18,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: outputOptions.map((mode) {
              return RadioListTile<String>(
                title: Text(
                  getVideoOutputLabel(context, mode),
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontSize: isLandscape ? 12 : 14,
                  ),
                ),
                subtitle: Text(
                  getVideoOutputDesc(context, mode),
                  style: TextStyle(
                    color: AppTheme.getTextMuted(context),
                    fontSize: isLandscape ? 9 : 11,
                  ),
                ),
                value: mode,
                groupValue: settings.videoOutput,
                onChanged: (value) async {
                  if (value != null) {
                    await settings.setVideoOutput(value);
                    await reinitMediaKitPlayer(context, settings);
                    Navigator.pop(dialogContext);
                    final strings = AppStrings.of(context);
                    showSuccess(
                      context,
                      (strings?.videoOutputSet ?? 'Video output set to: {mode}')
                          .replaceFirst(
                              '{mode}', getVideoOutputLabel(context, value)),
                    );
                  }
                },
                activeColor: AppTheme.getPrimaryColor(dialogContext),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 8 : 16,
                  vertical: isLandscape ? 0 : 4,
                ),
              );
            }).toList(),
          ),
        ),
      );
    },
  );
}

void showWindowsHwdecDialog(BuildContext context, SettingsProvider settings) {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;
  final isLandscape =
      screenWidth > 600 && screenWidth < 900 && screenHeight < screenWidth;
  final options = ['auto-safe', 'auto-copy', 'd3d11va', 'dxva2'];

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(dialogContext),
        contentPadding: EdgeInsets.fromLTRB(
          isLandscape ? 16 : 24,
          isLandscape ? 8 : 16,
          isLandscape ? 16 : 24,
          isLandscape ? 8 : 16,
        ),
        title: Text(
          AppStrings.of(context)?.windowsHwdecMode ?? 'Windows HW Decoder',
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontSize: isLandscape ? 14 : 18,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((mode) {
              return RadioListTile<String>(
                title: Text(
                  getWindowsHwdecLabel(context, mode),
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontSize: isLandscape ? 12 : 14,
                  ),
                ),
                subtitle: Text(
                  getWindowsHwdecDesc(context, mode),
                  style: TextStyle(
                    color: AppTheme.getTextMuted(context),
                    fontSize: isLandscape ? 9 : 11,
                  ),
                ),
                value: mode,
                groupValue: settings.windowsHwdecMode,
                onChanged: (value) async {
                  if (value != null) {
                    await settings.setWindowsHwdecMode(value);
                    await reinitMediaKitPlayer(context, settings);
                    Navigator.pop(dialogContext);
                    final strings = AppStrings.of(context);
                    showSuccess(
                      context,
                      (strings?.windowsHwdecModeSet ??
                              'Windows HW decode set to: {mode}')
                          .replaceFirst(
                              '{mode}', getWindowsHwdecLabel(context, value)),
                    );
                  }
                },
                activeColor: AppTheme.getPrimaryColor(dialogContext),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 8 : 16,
                  vertical: isLandscape ? 0 : 4,
                ),
              );
            }).toList(),
          ),
        ),
      );
    },
  );
}

void showD3d11vppDialog(BuildContext context, SettingsProvider settings) {
  const options = SettingsProvider.d3d11vppModes;

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(dialogContext),
        title: Text(
          AppStrings.of(context)?.d3d11vppMode ?? 'D3D11VPP Deinterlace',
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((mode) {
              return RadioListTile<String>(
                title: Text(
                  getD3d11vppLabel(context, mode),
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                  ),
                ),
                value: mode,
                groupValue: settings.d3d11vppMode,
                onChanged: (value) async {
                  if (value != null) {
                    await settings.setD3d11vppMode(value);
                    await reinitMediaKitPlayer(context, settings);
                    Navigator.pop(dialogContext);
                    showSuccess(
                      context,
                      '${AppStrings.of(context)?.d3d11vppMode ?? 'D3D11VPP Deinterlace'}: ${getD3d11vppLabel(context, value)}',
                    );
                  }
                },
                activeColor: AppTheme.getPrimaryColor(dialogContext),
              );
            }).toList(),
          ),
        ),
      );
    },
  );
}

Future<void> reinitMediaKitPlayer(
    BuildContext context, SettingsProvider settings) async {
  // 延迟到下一个事件循环，避免与当前帧的 build phase 冲突
  // 不使用 endOfFrame/addPostFrameCallback，避免引入额外帧调度
  // 导致 schedulerPhase 状态混乱
  await Future.delayed(Duration.zero);

  // Settings screen may appear without PlayerProvider in the widget tree.
  try {
    await context.read<PlayerProvider>().reinitializePlayer(
          bufferStrength: settings.bufferStrength,
        );
  } catch (_) {}
  // Reinitialize multi-screen players if available.
  try {
    await context.read<MultiScreenProvider>().reinitializePlayers(
          videoOutput: settings.videoOutput,
          windowsHwdecMode: settings.windowsHwdecMode,
          d3d11vppMode: settings.d3d11vppMode,
          allowSoftwareFallback: settings.allowSoftwareFallback,
          decodingMode: settings.decodingMode,
          bufferStrength: settings.bufferStrength,
        );
  } catch (_) {}
}

void showChannelMergeRuleDialog(
    BuildContext context, SettingsProvider settings) {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;
  final isLandscape =
      screenWidth > 600 && screenWidth < 900 && screenHeight < screenWidth;
  final options = ['name_group', 'name'];

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isLandscape ? 12 : 16),
        ),
        contentPadding: EdgeInsets.all(isLandscape ? 12 : 20),
        titlePadding: EdgeInsets.fromLTRB(
          isLandscape ? 16 : 24,
          isLandscape ? 12 : 20,
          isLandscape ? 16 : 24,
          isLandscape ? 8 : 16,
        ),
        title: Text(
          AppStrings.of(context)?.channelMergeRule ?? 'Channel Merge Rule',
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontSize: isLandscape ? 14 : 18,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((rule) {
              return RadioListTile<String>(
                title: Text(
                  channelMergeRuleLabel(context, rule),
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontSize: isLandscape ? 12 : 14,
                  ),
                ),
                subtitle: Text(
                  channelMergeRuleDescription(context, rule),
                  style: TextStyle(
                    color: AppTheme.getTextMuted(context),
                    fontSize: isLandscape ? 9 : 11,
                  ),
                ),
                value: rule,
                groupValue: settings.channelMergeRule,
                onChanged: (value) {
                  if (value != null) {
                    settings.setChannelMergeRule(value);
                    Navigator.pop(dialogContext);
                    final strings = AppStrings.of(context);
                    showSuccess(
                        context,
                        (strings?.channelMergeRuleSet ??
                                'Channel merge rule set to: {rule}')
                            .replaceFirst('{rule}',
                                channelMergeRuleLabel(context, value)));
                  }
                },
                activeColor: AppTheme.getPrimaryColor(dialogContext),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 8 : 16,
                  vertical: isLandscape ? 0 : 4,
                ),
                visualDensity: isLandscape ? VisualDensity.compact : null,
              );
            }).toList(),
          ),
        ),
      );
    },
  );
}

void showBufferStrengthDialog(BuildContext context, SettingsProvider settings) {
  final style = dialogStyle(context);
  final options = ['fast', 'balanced', 'stable'];
  final strings = AppStrings.of(context);
  final labels = {
    'fast': strings?.fastBuffer ?? 'Fast (Quick switching, may stutter)',
    'balanced': strings?.balancedBuffer ?? 'Balanced',
    'stable':
        strings?.stableBuffer ?? 'Stable (Slow switching, less stuttering)',
  };

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(context),
        shape: style['shape'],
        contentPadding: style['contentPadding'],
        titlePadding: style['titlePadding'],
        title: Text(
          strings?.bufferStrength ?? 'Buffer Strength',
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontSize: style['titleFontSize'],
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((strength) {
              return RadioListTile<String>(
                title: Text(
                  labels[strength] ?? strength,
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontSize: style['itemFontSize'],
                  ),
                ),
                value: strength,
                groupValue: settings.bufferStrength,
                onChanged: (value) async {
                  if (value != null) {
                    await settings.setBufferStrength(value);
                    await reinitMediaKitPlayer(context, settings);
                    Navigator.pop(dialogContext);
                  }
                },
                activeColor: AppTheme.getPrimaryColor(dialogContext),
                contentPadding: style['itemPadding'],
                visualDensity: style['visualDensity'],
              );
            }).toList(),
          ),
        ),
      );
    },
  );
}

void showProgressBarModeDialog(
    BuildContext context, SettingsProvider settings) {
  final style = dialogStyle(context);
  final options = ['auto', 'always', 'never'];
  final strings = AppStrings.of(context);
  final labels = {
    'auto': strings?.progressBarModeAuto ?? '自动检测',
    'always': strings?.progressBarModeAlways ?? '始终显示',
    'never': strings?.progressBarModeNever ?? '不显示',
  };
  final descriptions = {
    'auto': strings?.progressBarModeAutoDesc ?? '根据内容类型自动显示（点播/回放显示，直播隐藏）',
    'always': strings?.progressBarModeAlwaysDesc ?? '所有内容都显示进度条',
    'never': strings?.progressBarModeNeverDesc ?? '所有内容都不显示进度条',
  };

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(context),
        shape: style['shape'],
        contentPadding: style['contentPadding'],
        titlePadding: style['titlePadding'],
        title: Text(
          strings?.progressBarMode ?? '进度条显示',
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontSize: style['titleFontSize'],
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((mode) {
              return RadioListTile<String>(
                title: Text(
                  labels[mode] ?? mode,
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontSize: style['itemFontSize'],
                  ),
                ),
                subtitle: Text(
                  descriptions[mode] ?? '',
                  style: TextStyle(
                    color: AppTheme.getTextMuted(context),
                    fontSize: style['subtitleFontSize'],
                  ),
                ),
                value: mode,
                groupValue: settings.progressBarMode,
                onChanged: (value) {
                  if (value != null) {
                    settings.setProgressBarMode(value);
                    Navigator.pop(dialogContext);
                    final message =
                        (strings?.progressBarModeSet ?? '进度条显示已设置为：{mode}')
                            .replaceFirst('{mode}', labels[value] ?? value);
                    showSuccess(context, message);
                  }
                },
                activeColor: AppTheme.getPrimaryColor(dialogContext),
                contentPadding: style['itemPadding'],
                visualDensity: style['visualDensity'],
              );
            }).toList(),
          ),
        ),
      );
    },
  );
}

void showUserAgentDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const UserAgentDialog(),
  );
}

void showSeekStepDialog(BuildContext context, SettingsProvider settings) {
  final style = dialogStyle(context);
  final options = [5, 10, 30, 60, 120];
  final strings = AppStrings.of(context);
  final labels = {
    5: strings?.seekStep5s ?? '5秒',
    10: strings?.seekStep10s ?? '10秒',
    30: strings?.seekStep30s ?? '30秒',
    60: strings?.seekStep60s ?? '60秒',
    120: strings?.seekStep120s ?? '120秒',
  };

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: style['backgroundColor'],
        shape: style['shape'],
        titlePadding: style['titlePadding'],
        title: Text(
          strings?.seekStepSeconds ?? '快进/快退跨度',
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        contentPadding: style['contentPadding'],
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((seconds) {
              return RadioListTile<int>(
                title: Text(
                  labels[seconds] ?? '$seconds秒',
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(dialogContext),
                    fontSize: 14,
                  ),
                ),
                value: seconds,
                groupValue: settings.seekStepSeconds,
                onChanged: (value) {
                  if (value != null) {
                    settings.setSeekStepSeconds(value);
                    Navigator.pop(dialogContext);
                    final message =
                        (strings?.seekStepSet ?? '快进/快退跨度已设置为：{seconds}秒')
                            .replaceFirst('{seconds}', value.toString());
                    showSuccess(context, message);
                  }
                },
                activeColor: AppTheme.getPrimaryColor(dialogContext),
                contentPadding: style['itemPadding'],
                visualDensity: style['visualDensity'],
              );
            }).toList(),
          ),
        ),
      );
    },
  );
}

void showVolumeBoostDialog(BuildContext context, SettingsProvider settings) {
  final style = dialogStyle(context);
  final options = [-10, -5, 0, 5, 10, 15, 20];

  showDialog(
    context: context,
    builder: (dialogContext) {
      final strings = AppStrings.of(context);
      return AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(context),
        shape: style['shape'],
        contentPadding: style['contentPadding'],
        titlePadding: style['titlePadding'],
        title: Text(
          strings?.volumeBoost ?? 'Volume Boost',
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontSize: style['titleFontSize'],
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.map((db) {
                return RadioListTile<int>(
                  title: Text(
                    db == 0
                        ? '${strings?.noBoost ?? "No boost"} (0 dB)'
                        : '${db > 0 ? '+' : ''}$db dB',
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontSize: style['itemFontSize'],
                    ),
                  ),
                  subtitle: Text(
                    volumeBoostDescription(context, db),
                    style: TextStyle(
                      color: AppTheme.getTextMuted(context),
                      fontSize: style['subtitleFontSize'],
                    ),
                  ),
                  value: db,
                  groupValue: settings.volumeBoost,
                  onChanged: (value) {
                    if (value != null) {
                      settings.setVolumeBoost(value);
                      Navigator.pop(dialogContext);
                      final strings = AppStrings.of(context);
                      final boostValue = value == 0
                          ? (strings?.noBoostValue ?? 'No boost')
                          : '${value > 0 ? '+' : ''}$value dB';
                      showSuccess(
                          context,
                          (strings?.volumeBoostSet ??
                                  'Volume boost set to {value}')
                              .replaceFirst('{value}', boostValue));
                    }
                  },
                  activeColor: AppTheme.getPrimaryColor(dialogContext),
                  contentPadding: style['itemPadding'],
                  visualDensity: style['visualDensity'],
                );
              }).toList(),
            ),
          ),
        ),
      );
    },
  );
}

