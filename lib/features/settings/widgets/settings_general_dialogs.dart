import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/services/service_locator.dart';
import '../widgets/settings_dialog_helpers.dart';
import '../providers/settings_provider.dart';
import '../../epg/providers/epg_provider.dart';

import 'settings_feedback.dart';

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
