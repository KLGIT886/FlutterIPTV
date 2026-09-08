import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/color_scheme_dialog.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/services/service_locator.dart';
import '../widgets/user_agent_dialog.dart';
import '../widgets/settings_dialog_helpers.dart';
import '../widgets/settings_playback_labels.dart';
import '../../player/providers/player_provider.dart';
import '../../multi_screen/providers/multi_screen_provider.dart';
import '../providers/settings_provider.dart';
import '../../epg/providers/epg_provider.dart';

/// 设置页"对话框 + 通用成功/失败提示 + 播放器重建"顶层方法。
/// 从 `settings_screen.dart` 纯搬移，不改任何逻辑与文案。

void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AppTheme.successColor,
      duration: const Duration(seconds: 2),
    ),
  );
}

void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AppTheme.errorColor,
      duration: const Duration(seconds: 3),
    ),
  );
}

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

void showHomeFontSizeDialog(BuildContext context, SettingsProvider settings) {
  const minScale = 0.8;
  const maxScale = 1.2; // 范围：80%~120%
  const divisions = 8; // 步长 0.05

  showDialog(
    context: context,
    builder: (dialogContext) {
      final strings = AppStrings.of(context);
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 300,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.getGlassBorderColor(context)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题行
              Row(
                children: [
                  Icon(Icons.format_size_rounded,
                      color: AppTheme.getPrimaryColor(context), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings?.homeFontSize ?? '首页字体大小',
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // 描述 + 当前值
              Row(
                children: [
                  Expanded(
                    child: Text(
                      strings?.homeFontSizeDesc ?? '调整首页节目名称和EPG节目单字体大小',
                      style: TextStyle(
                        color: AppTheme.getTextMuted(context),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(settings.homeFontScale * 100).round()}%',
                    style: TextStyle(
                      color: AppTheme.getPrimaryColor(context),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // 滑块
              StatefulBuilder(
                builder: (context, setState) {
                  final scale =
                      settings.homeFontScale.clamp(minScale, maxScale);
                  final percent = (scale * 100).round();
                  return SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 8),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: scale,
                      min: minScale,
                      max: maxScale,
                      divisions: divisions,
                      label: '$percent%',
                      activeColor: AppTheme.getPrimaryColor(context),
                      inactiveColor:
                          AppTheme.getTextMuted(context).withOpacity(0.2),
                      onChanged: (value) {
                        setState(() {
                          settings.setHomeFontScale(value);
                        });
                      },
                    ),
                  );
                },
              ),
              // 操作按钮
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      settings.setHomeFontScale(1.0);
                      Navigator.pop(dialogContext);
                      final s = AppStrings.of(context);
                      showSuccess(
                          context,
                          (s?.homeFontSizeSet ?? '首页字体大小已设置为 {value}')
                              .replaceFirst('{value}', '100%'));
                    },
                    icon: Icon(Icons.restart_alt_rounded,
                        color: AppTheme.getTextMuted(context), size: 15),
                    label: Text(
                      strings?.reset ?? '重置',
                      style: TextStyle(
                        color: AppTheme.getTextMuted(context),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.getPrimaryColor(context),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      strings?.close ?? '关闭',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

void showRefreshIntervalDialog(
    BuildContext context, SettingsProvider settings) {
  final style = dialogStyle(context);
  final options = [6, 12, 24, 48, 72];

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(context),
        shape: style['shape'],
        contentPadding: style['contentPadding'],
        titlePadding: style['titlePadding'],
        title: Text(
          AppStrings.of(context)?.refreshInterval ?? 'Refresh Interval',
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontSize: style['titleFontSize'],
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((hours) {
              return RadioListTile<int>(
                title: Text(
                  hours < 24
                      ? '$hours ${AppStrings.of(context)?.hours ?? 'hours'}'
                      : '${hours ~/ 24} ${hours ~/ 24 > 1 ? (AppStrings.of(context)?.days ?? 'days') : (AppStrings.of(context)?.day ?? 'day')}',
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontSize: style['itemFontSize'],
                  ),
                ),
                value: hours,
                groupValue: settings.refreshInterval,
                onChanged: (value) {
                  if (value != null) {
                    settings.setRefreshInterval(value);
                    Navigator.pop(dialogContext);
                    final strings = AppStrings.of(context);
                    showSuccess(context,
                        'Refresh interval: $value ${strings?.hours ?? 'hours'}');
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

void showEpgUrlDialog(BuildContext context, SettingsProvider settings) {
  final controller = TextEditingController(text: settings.epgUrl);

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(context),
        title: Text(
          AppStrings.of(context)?.epgUrl ?? 'EPG URL',
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
          decoration: InputDecoration(
            hintText:
                AppStrings.of(context)?.enterEpgUrl ?? 'Enter EPG XMLTV URL',
            hintStyle: TextStyle(color: AppTheme.getTextMuted(context)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppStrings.of(context)?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = controller.text.trim().isEmpty
                  ? null
                  : controller.text.trim();
              final oldUrl = settings.epgUrl;

              // 保存新 URL
              await settings.setEpgUrl(newUrl);
              Navigator.pop(dialogContext);

              // 如果 URL 变化了，清除旧数据并加载新数据
              if (newUrl != oldUrl) {
                final epgProvider = context.read<EpgProvider>();
                epgProvider.clear();
                final strings = AppStrings.of(context);

                if (newUrl != null && newUrl.isNotEmpty && settings.enableEpg) {
                  // User-initiated action, show loading state
                  final success =
                      await epgProvider.loadEpg(newUrl, silent: false);
                  if (success) {
                    showSuccess(
                        context,
                        strings?.epgUrlSavedAndLoaded ??
                            'EPG URL saved and loaded successfully');
                  } else {
                    showError(
                        context,
                        strings?.epgUrlSavedButFailed ??
                            'EPG URL saved but failed to load');
                  }
                } else if (newUrl == null) {
                  showSuccess(
                      context, strings?.epgUrlCleared ?? 'EPG URL cleared');
                } else {
                  showSuccess(context, strings?.epgUrlSaved ?? 'EPG URL saved');
                }
              }
            },
            child: Text(AppStrings.of(context)?.save ?? 'Save'),
          ),
        ],
      );
    },
  );
}

void confirmResetSettings(BuildContext context, SettingsProvider settings) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(context),
        title: Text(
          AppStrings.of(context)?.resetSettings ?? 'Reset Settings',
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
        ),
        content: Text(
          AppStrings.of(context)?.resetConfirm ??
              'Are you sure you want to reset all settings to their default values?',
          style: TextStyle(color: AppTheme.getTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppStrings.of(context)?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              settings.resetSettings();
              context.read<EpgProvider>().clear();
              Navigator.pop(dialogContext);
              final strings = AppStrings.of(context);
              showSuccess(
                  context,
                  strings?.allSettingsReset ??
                      'All settings have been reset to default values');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: Text(AppStrings.of(context)?.reset ?? 'Reset'),
          ),
        ],
      );
    },
  );
}

void showLanguageDialog(BuildContext context, SettingsProvider settings) {
  // 获取当前设置的语言代码，null 表示跟随系统
  final currentLang = settings.locale?.languageCode;

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(context),
        title: Text(
          AppStrings.of(context)?.language ?? 'Language',
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String?>(
              title: Text(
                AppStrings.of(context)?.followSystem ?? '跟随系统',
                style: TextStyle(color: AppTheme.getTextPrimary(context)),
              ),
              value: null,
              groupValue: currentLang,
              onChanged: (value) {
                settings.setLocale(null);
                Navigator.pop(dialogContext);
                showSuccess(
                    context,
                    AppStrings.of(context)?.languageFollowSystem ??
                        '已设置为跟随系统语言');
              },
              activeColor: AppTheme.getPrimaryColor(dialogContext),
            ),
            RadioListTile<String?>(
              title: Text(
                'English',
                style: TextStyle(color: AppTheme.getTextPrimary(context)),
              ),
              value: 'en',
              groupValue: currentLang,
              onChanged: (value) {
                settings.setLocale(const Locale('en'));
                Navigator.pop(dialogContext);
                showSuccess(context, 'Language changed to English');
              },
              activeColor: AppTheme.getPrimaryColor(dialogContext),
            ),
            RadioListTile<String?>(
              title: Text(
                AppStrings.of(context)?.chinese ?? '中文',
                style: TextStyle(color: AppTheme.getTextPrimary(context)),
              ),
              value: 'zh',
              groupValue: currentLang,
              onChanged: (value) {
                settings.setLocale(const Locale('zh'));
                Navigator.pop(dialogContext);
                final strings = AppStrings.of(context);
                showSuccess(
                    context,
                    strings?.languageSwitchedToChinese ??
                        'Language switched to Chinese');
              },
              activeColor: AppTheme.getPrimaryColor(dialogContext),
            ),
          ],
        ),
      );
    },
  );
}

void showThemeModeDialog(BuildContext context, SettingsProvider settings) {
  final style = dialogStyle(context);
  final options = ['system', 'light', 'dark'];

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(context),
        shape: style['shape'],
        contentPadding: style['contentPadding'],
        titlePadding: style['titlePadding'],
        title: Text(
          AppStrings.of(context)?.theme ?? 'Theme',
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
                  themeModeLabel(context, mode),
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontSize: style['itemFontSize'],
                  ),
                ),
                value: mode,
                groupValue: settings.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    settings.setThemeMode(value);
                    Navigator.pop(dialogContext);
                    final strings = AppStrings.of(context);
                    showSuccess(
                        context,
                        (strings?.themeChangedMessage ??
                                'Theme changed: {theme}')
                            .replaceFirst(
                                '{theme}', themeModeLabel(context, value)));
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

void showLogLevelDialog(BuildContext context, SettingsProvider settings) {
  final options = ['debug', 'release', 'off'];

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(context),
        title: Text(
          AppStrings.of(context)?.logLevel ?? 'Log Level',
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((level) {
            return RadioListTile<String>(
              title: Text(
                logLevelLabel(context, level),
                style: TextStyle(color: AppTheme.getTextPrimary(context)),
              ),
              subtitle: Text(
                logLevelDescription(context, level),
                style: TextStyle(
                    color: AppTheme.getTextSecondary(context), fontSize: 12),
              ),
              value: level,
              groupValue: settings.logLevel,
              onChanged: (value) async {
                if (value != null) {
                  await settings.setLogLevel(value);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    showSuccess(context,
                        '${AppStrings.of(context)?.logLevel ?? "Log level"}: ${logLevelLabel(context, value)}');
                  }
                }
              },
              activeColor: AppTheme.getPrimaryColor(dialogContext),
            );
          }).toList(),
        ),
      );
    },
  );
}

void checkForUpdates(BuildContext context) {
  ServiceLocator.updateManager.manualCheckForUpdate(context);
}

void showScreenPositionDialog(BuildContext context, SettingsProvider settings) {
  final options = [1, 2, 3, 4];
  final strings = AppStrings.of(context);

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(context),
        title: Text(
          strings?.defaultScreenPosition ?? 'Default Screen Position',
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings?.screenPositionDesc ??
                  'Choose which screen position to use by default when clicking a channel:',
              style: TextStyle(
                  color: AppTheme.getTextSecondary(context), fontSize: 12),
            ),
            const SizedBox(height: 16),
            // 显示2x2网格示意图
            Container(
              width: 120,
              height: 90,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.getTextMuted(context)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: AppTheme.getTextMuted(context)
                                      .withOpacity(0.3)),
                              color: settings.defaultScreenPosition == 1
                                  ? AppTheme.getPrimaryColor(context)
                                      .withOpacity(0.3)
                                  : null,
                            ),
                            child: Center(
                                child: Text('1',
                                    style: TextStyle(
                                        color: AppTheme.getTextPrimary(context),
                                        fontSize: 12))),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: AppTheme.getTextMuted(context)
                                      .withOpacity(0.3)),
                              color: settings.defaultScreenPosition == 2
                                  ? AppTheme.getPrimaryColor(context)
                                      .withOpacity(0.3)
                                  : null,
                            ),
                            child: Center(
                                child: Text('2',
                                    style: TextStyle(
                                        color: AppTheme.getTextPrimary(context),
                                        fontSize: 12))),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: AppTheme.getTextMuted(context)
                                      .withOpacity(0.3)),
                              color: settings.defaultScreenPosition == 3
                                  ? AppTheme.getPrimaryColor(context)
                                      .withOpacity(0.3)
                                  : null,
                            ),
                            child: Center(
                                child: Text('3',
                                    style: TextStyle(
                                        color: AppTheme.getTextPrimary(context),
                                        fontSize: 12))),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: AppTheme.getTextMuted(context)
                                      .withOpacity(0.3)),
                              color: settings.defaultScreenPosition == 4
                                  ? AppTheme.getPrimaryColor(context)
                                      .withOpacity(0.3)
                                  : null,
                            ),
                            child: Center(
                                child: Text('4',
                                    style: TextStyle(
                                        color: AppTheme.getTextPrimary(context),
                                        fontSize: 12))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...options.map((position) {
              return RadioListTile<int>(
                title: Text(
                  screenPositionLabel(context, position),
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                ),
                value: position,
                groupValue: settings.defaultScreenPosition,
                onChanged: (value) {
                  if (value != null) {
                    settings.setDefaultScreenPosition(value);
                    Navigator.pop(dialogContext);
                    final strings = AppStrings.of(context);
                    showSuccess(
                        context,
                        (strings?.screenPositionSet ??
                                'Default screen position set to: {position}')
                            .replaceFirst('{position}',
                                screenPositionLabel(context, value)));
                  }
                },
                activeColor: AppTheme.getPrimaryColor(dialogContext),
              );
            }),
          ],
        ),
      );
    },
  );
}

void showPageTransitionDialog(BuildContext context, SettingsProvider settings) {
  final style = dialogStyle(context);
  final strings = AppStrings.of(context);

  final animations = [
    {
      'value': 'fade',
      'label': strings?.transitionFade ?? 'Fade',
      'desc': strings?.transitionFadeDesc ?? 'Smooth fade in/out effect'
    },
    {
      'value': 'slide',
      'label': strings?.transitionSlide ?? 'Slide',
      'desc': strings?.transitionSlideDesc ?? 'Slide from right to left'
    },
    {
      'value': 'scale',
      'label': strings?.transitionScale ?? 'Scale',
      'desc': strings?.transitionScaleDesc ?? 'Scale in effect'
    },
    {
      'value': 'material',
      'label': strings?.transitionMaterial ?? 'Material (Android)',
      'desc': strings?.transitionMaterialDesc ?? 'Android native animation'
    },
    {
      'value': 'cupertino',
      'label': strings?.transitionCupertino ?? 'Cupertino (iOS)',
      'desc': strings?.transitionCupertinoDesc ??
          'iOS native animation with parallax'
    },
    {
      'value': 'none',
      'label': strings?.transitionNone ?? 'None',
      'desc': strings?.transitionNoneDesc ?? 'Direct switch, no animation'
    },
  ];

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(context),
        shape: style['shape'] as ShapeBorder,
        title: Text(
          strings?.pageTransitionAnimation ?? 'Page Transition Animation',
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: animations.map((anim) {
              final isSelected =
                  settings.pageTransitionAnimation == anim['value'];
              return RadioListTile<String>(
                title: Text(
                  anim['label'] as String,
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  anim['desc'] as String,
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 12,
                  ),
                ),
                value: anim['value'] as String,
                groupValue: settings.pageTransitionAnimation,
                activeColor: AppTheme.getPrimaryColor(context),
                onChanged: (value) {
                  if (value != null) {
                    settings.setPageTransitionAnimation(value);
                    Navigator.pop(dialogContext);
                    showSuccess(
                        context,
                        strings?.pageTransitionSet ??
                            'Page transition animation set');
                  }
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              strings?.close ?? 'Close',
              style: TextStyle(color: AppTheme.getPrimaryColor(context)),
            ),
          ),
        ],
      );
    },
  );
}

void showFontFamilyDialog(BuildContext context, SettingsProvider settings) {
  final style = dialogStyle(context);
  final languageCode = settings.locale?.languageCode ??
      WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  final fonts = AppTheme.getAvailableFonts(languageCode);
  final strings = AppStrings.of(context);

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(context),
        shape: style['shape'],
        contentPadding: style['contentPadding'],
        titlePadding: style['titlePadding'],
        title: Text(
          strings?.fontFamily ?? '字体',
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontSize: style['titleFontSize'],
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: fonts.length,
            itemBuilder: (context, index) {
              final font = fonts[index];
              final resolvedFont = AppTheme.resolveFontFamily(font);
              return RadioListTile<String>(
                title: Text(
                  fontFamilyLabel(context, font, settings),
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontFamily: resolvedFont,
                    fontSize: style['itemFontSize'],
                  ),
                ),
                value: font,
                groupValue: settings.fontFamily,
                onChanged: (value) {
                  if (value != null) {
                    settings.setFontFamily(value);
                    Navigator.pop(dialogContext);
                    final fontLabel = fontFamilyLabel(context, value, settings);
                    final message = (strings?.fontChanged ?? '字体已更改为 {font}')
                        .replaceAll('{font}', fontLabel);
                    showSuccess(context, message);
                  }
                },
                activeColor: AppTheme.getPrimaryColor(dialogContext),
                contentPadding: style['itemPadding'],
                visualDensity: style['visualDensity'],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: style['isLandscape'] ? 12.0 : 16.0,
                vertical: style['isLandscape'] ? 6.0 : 8.0,
              ),
            ),
            child: Text(
              AppStrings.of(context)?.cancel ?? 'Cancel',
              style: TextStyle(fontSize: style['itemFontSize']),
            ),
          ),
        ],
      );
    },
  );
}

void showOrientationDialog(BuildContext context, SettingsProvider settings) {
  final style = dialogStyle(context);
  final options = ['portrait', 'landscape', 'auto'];

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(context),
        shape: style['shape'],
        contentPadding: style['contentPadding'],
        titlePadding: style['titlePadding'],
        title: Text(
          '屏幕方向',
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontSize: style['titleFontSize'],
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((orientation) {
              IconData icon;
              switch (orientation) {
                case 'landscape':
                  icon = Icons.screen_rotation_rounded;
                  break;
                case 'portrait':
                  icon = Icons.stay_current_portrait_rounded;
                  break;
                case 'auto':
                default:
                  icon = Icons.screen_rotation_alt_rounded;
                  break;
              }

              return RadioListTile<String>(
                title: Row(
                  children: [
                    Icon(
                      icon,
                      color: AppTheme.getTextPrimary(context),
                      size: style['isLandscape'] ? 16.0 : 20.0,
                    ),
                    SizedBox(width: style['isLandscape'] ? 8.0 : 12.0),
                    Text(
                      orientationLabel(context, orientation),
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontSize: style['itemFontSize'],
                      ),
                    ),
                  ],
                ),
                value: orientation,
                groupValue: settings.mobileOrientation,
                onChanged: (value) async {
                  if (value != null) {
                    await settings.setMobileOrientation(value);

                    // 应用屏幕方向
                    List<DeviceOrientation> orientations;
                    switch (value) {
                      case 'landscape':
                        orientations = [
                          DeviceOrientation.landscapeLeft,
                          DeviceOrientation.landscapeRight,
                        ];
                        break;
                      case 'portrait':
                        orientations = [
                          DeviceOrientation.portraitUp,
                        ];
                        break;
                      case 'auto':
                      default:
                        orientations = [
                          DeviceOrientation.portraitUp,
                          DeviceOrientation.landscapeLeft,
                          DeviceOrientation.landscapeRight,
                        ];
                        break;
                    }

                    await SystemChrome.setPreferredOrientations(orientations);

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                      showSuccess(context,
                          '屏幕方向已设置为: ${orientationLabel(context, value)}');
                    }
                  }
                },
                activeColor: AppTheme.getPrimaryColor(dialogContext),
                contentPadding: style['itemPadding'],
                visualDensity: style['visualDensity'],
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: style['isLandscape'] ? 12.0 : 16.0,
                vertical: style['isLandscape'] ? 6.0 : 8.0,
              ),
            ),
            child: Text(
              AppStrings.of(context)?.cancel ?? 'Cancel',
              style: TextStyle(fontSize: style['itemFontSize']),
            ),
          ),
        ],
      );
    },
  );
}

void showLogoCacheDaysDialog(BuildContext context, SettingsProvider settings) {
  final style = dialogStyle(context);
  const dayOptions = [1, 3, 7, 14, 30, 60, 90];

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppTheme.getSurfaceColor(dialogContext),
      shape: style['shape'],
      contentPadding: style['contentPadding'],
      titlePadding: style['titlePadding'],
      title: Text(
        AppStrings.of(context)?.logoCacheDays ?? 'Cache Retention',
        style: TextStyle(fontSize: style['titleFontSize']),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: dayOptions
              .map((days) => RadioListTile<int>(
                    title: Text(
                      logoCacheDaysLabel(context, days),
                      style: TextStyle(fontSize: style['itemFontSize']),
                    ),
                    subtitle: Text(
                      logoCacheDaysHint(context, days),
                      style: TextStyle(fontSize: style['subtitleFontSize']),
                    ),
                    value: days,
                    groupValue: settings.logoCacheDays,
                    onChanged: (value) async {
                      if (value != null) {
                        await settings.setLogoCacheDays(value);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          showSuccess(
                            context,
                            '${AppStrings.of(context)?.logoCacheDays ?? 'Cache Retention'}: ${logoCacheDaysLabel(context, value)}',
                          );
                        }
                      }
                    },
                    activeColor: AppTheme.getPrimaryColor(dialogContext),
                    contentPadding: style['itemPadding'],
                    visualDensity: style['visualDensity'],
                  ))
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(
            AppStrings.of(context)?.cancel ?? 'Cancel',
            style: TextStyle(fontSize: style['itemFontSize']),
          ),
        ),
      ],
    ),
  );
}

void showLogoCacheMaxObjectsDialog(
    BuildContext context, SettingsProvider settings) {
  final style = dialogStyle(context);
  const objectOptions = [200, 500, 1000, 2000, 5000];

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppTheme.getSurfaceColor(dialogContext),
      shape: style['shape'],
      contentPadding: style['contentPadding'],
      titlePadding: style['titlePadding'],
      title: Text(
        AppStrings.of(context)?.logoCacheMaxObjects ?? 'Max Cache Items',
        style: TextStyle(fontSize: style['titleFontSize']),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: objectOptions
              .map((count) => RadioListTile<int>(
                    title: Text(
                      logoCacheMaxObjectsLabel(context, count),
                      style: TextStyle(fontSize: style['itemFontSize']),
                    ),
                    subtitle: Text(
                      logoCacheMaxObjectsHint(context, count),
                      style: TextStyle(fontSize: style['subtitleFontSize']),
                    ),
                    value: count,
                    groupValue: settings.logoCacheMaxObjects,
                    onChanged: (value) async {
                      if (value != null) {
                        await settings.setLogoCacheMaxObjects(value);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          showSuccess(
                            context,
                            '${AppStrings.of(context)?.logoCacheMaxObjects ?? 'Max Cache Items'}: ${logoCacheMaxObjectsLabel(context, value)}',
                          );
                        }
                      }
                    },
                    activeColor: AppTheme.getPrimaryColor(dialogContext),
                    contentPadding: style['itemPadding'],
                    visualDensity: style['visualDensity'],
                  ))
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(
            AppStrings.of(context)?.cancel ?? 'Cancel',
            style: TextStyle(fontSize: style['itemFontSize']),
          ),
        ),
      ],
    ),
  );
}

Future<void> clearLogoCacheAction(BuildContext context) async {
  final strings = AppStrings.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppTheme.getSurfaceColor(dialogContext),
      title: Text(strings?.clearLogoCacheConfirmTitle ?? 'Clear Logo Cache?'),
      content: Text(strings?.clearLogoCacheConfirmDesc ??
          'All cached channel logo images will be deleted. Logos will be re-downloaded the next time they are needed.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(strings?.cancel ?? 'Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(strings?.clear ?? 'Clear'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;
  if (!context.mounted) return;

  try {
    await ServiceLocator.logoCache.clearAllCache();
    if (context.mounted) {
      showSuccess(context, strings?.logoCacheCleared ?? 'Logo cache cleared');
    }
  } catch (e) {
    if (context.mounted) {
      showError(context,
          '${strings?.logoCacheClearFailed ?? 'Failed to clear logo cache'}: $e');
    }
  }
}
