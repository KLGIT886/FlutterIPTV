import 'package:material_ui/material_ui.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../core/theme/color_scheme_manager.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/constants/user_agent_presets.dart';
import '../providers/settings_provider.dart';

/// 设置页"对话框样式 + 标签/文案"纯工具方法。
/// 从 `settings_screen.dart` 纯搬移：仅依赖 context / settings / 参数与各纯常量，
/// 不依赖任何 State 字段，故提为顶层函数。纯搬移，未改逻辑与文案。

Map<String, dynamic> dialogStyle(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;
  final isLandscape =
      screenWidth > 600 && screenWidth < 900 && screenHeight < screenWidth;

  return {
    'isLandscape': isLandscape,
    'shape': RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(isLandscape ? 12 : 16),
    ),
    'contentPadding': EdgeInsets.all(isLandscape ? 12 : 20),
    'titlePadding': EdgeInsets.fromLTRB(
      isLandscape ? 16 : 24,
      isLandscape ? 12 : 20,
      isLandscape ? 16 : 24,
      isLandscape ? 8 : 16,
    ),
    'titleFontSize': isLandscape ? 14.0 : 18.0,
    'itemFontSize': isLandscape ? 12.0 : 14.0,
    'subtitleFontSize': isLandscape ? 9.0 : 11.0,
    'itemPadding': EdgeInsets.symmetric(
      horizontal: isLandscape ? 8.0 : 16.0,
      vertical: isLandscape ? 0.0 : 4.0,
    ),
    'visualDensity': isLandscape ? VisualDensity.compact : null,
  };
}

String currentLanguageLabel(BuildContext context, SettingsProvider settings) {
  final locale = settings.locale;
  final strings = AppStrings.of(context);
  if (locale == null) {
    // 没有设置，显示"跟随系统"
    final systemLocale = Localizations.localeOf(context);
    final systemLang = systemLocale.languageCode == 'zh'
        ? (strings?.chinese ?? '中文')
        : 'English';
    return '${strings?.followSystem ?? "Follow system"} ($systemLang)';
  }
  // 根据保存的设置显示
  if (locale.languageCode == 'zh') {
    return strings?.chinese ?? '中文';
  }
  return strings?.english ?? 'English';
}

String currentColorSchemeName(BuildContext context, SettingsProvider settings) {
  final strings = AppStrings.of(context);
  final manager = ColorSchemeManager.instance;

  // 判断当前是黑暗还是明亮模式
  final darkMode = isDarkMode(context, settings);
  final schemeId =
      darkMode ? settings.darkColorScheme : settings.lightColorScheme;
  final scheme = darkMode
      ? manager.getDarkScheme(schemeId)
      : manager.getLightScheme(schemeId);

  // 返回配色名称
  switch (scheme.nameKey) {
    case 'colorSchemeLotus':
      return strings?.colorSchemeLotus ?? 'Lotus';
    case 'colorSchemeOcean':
      return strings?.colorSchemeOcean ?? 'Ocean';
    case 'colorSchemeForest':
      return strings?.colorSchemeForest ?? 'Forest';
    case 'colorSchemeSunset':
      return strings?.colorSchemeSunset ?? 'Sunset';
    case 'colorSchemeLavender':
      return strings?.colorSchemeLavender ?? 'Lavender';
    case 'colorSchemeMidnight':
      return strings?.colorSchemeMidnight ?? 'Midnight';
    case 'colorSchemeLotusLight':
      return strings?.colorSchemeLotusLight ?? 'Lotus Light';
    case 'colorSchemeSky':
      return strings?.colorSchemeSky ?? 'Sky';
    case 'colorSchemeSpring':
      return strings?.colorSchemeSpring ?? 'Spring';
    case 'colorSchemeCoral':
      return strings?.colorSchemeCoral ?? 'Coral';
    case 'colorSchemeViolet':
      return strings?.colorSchemeViolet ?? 'Violet';
    case 'colorSchemeClassic':
      return strings?.colorSchemeClassic ?? 'Classic';
    default:
      return scheme.id;
  }
}

bool isDarkMode(BuildContext context, SettingsProvider settings) {
  if (settings.themeMode == 'dark') {
    return true;
  } else if (settings.themeMode == 'light') {
    return false;
  } else {
    // 跟随系统
    final brightness = MediaQuery.of(context).platformBrightness;
    return brightness == Brightness.dark;
  }
}

String platformName() {
  if (PlatformDetector.isTV) return 'Android TV';
  if (PlatformDetector.isAndroid) return 'Android';
  if (PlatformDetector.isWindows) return 'Windows';
  return 'Unknown';
}

String channelMergeRuleLabel(BuildContext context, String rule) {
  final strings = AppStrings.of(context);
  switch (rule) {
    case 'name':
      return strings?.mergeByName ?? 'Merge by Name';
    case 'name_group':
    default:
      return strings?.mergeByNameGroup ?? 'Merge by Name + Group';
  }
}

String channelMergeRuleDescription(BuildContext context, String rule) {
  final strings = AppStrings.of(context);
  switch (rule) {
    case 'name':
      return strings?.mergeByNameDesc ??
          'Merge channels with same name across all groups';
    case 'name_group':
    default:
      return strings?.mergeByNameGroupDesc ??
          'Only merge channels with same name AND group';
  }
}

String bufferStrengthLabel(BuildContext context, String strength) {
  final strings = AppStrings.of(context);
  switch (strength) {
    case 'fast':
      return strings?.fastBuffer ?? 'Fast (Quick switching, may stutter)';
    case 'balanced':
      return strings?.balancedBuffer ?? 'Balanced';
    case 'stable':
      return strings?.stableBuffer ??
          'Stable (Slow switching, less stuttering)';
    default:
      return strength;
  }
}

String progressBarModeLabel(BuildContext context, String mode) {
  final strings = AppStrings.of(context);
  switch (mode) {
    case 'auto':
      return strings?.progressBarModeAuto ?? '自动检测';
    case 'always':
      return strings?.progressBarModeAlways ?? '始终显示';
    case 'never':
      return strings?.progressBarModeNever ?? '不显示';
    default:
      return strings?.progressBarModeAuto ?? '自动检测';
  }
}

String userAgentLabel(BuildContext context, String userAgent) {
  // Check if it matches a preset
  final presetKey = UserAgentPresets.getKeyByValue(userAgent);
  if (presetKey != null) {
    final strings = AppStrings.of(context);
    switch (presetKey) {
      case 'wget':
        return '${strings?.userAgentPresetWget ?? 'Wget (Default)'}: $userAgent';
      case 'chrome_windows':
        return '${strings?.userAgentPresetChromeWin ?? 'Chrome Windows'}: ${userAgent.substring(0, 50)}...';
      case 'chrome_mac':
        return '${strings?.userAgentPresetChromeMac ?? 'Chrome Mac'}: ${userAgent.substring(0, 50)}...';
      case 'firefox':
        return '${strings?.userAgentPresetFirefox ?? 'Firefox'}: ${userAgent.substring(0, 50)}...';
      case 'safari':
        return '${strings?.userAgentPresetSafari ?? 'Safari'}: ${userAgent.substring(0, 50)}...';
      case 'edge':
        return '${strings?.userAgentPresetEdge ?? 'Edge'}: ${userAgent.substring(0, 50)}...';
      case 'vlc':
        return '${strings?.userAgentPresetVLC ?? 'VLC'}: $userAgent';
      case 'ffmpeg':
        return '${strings?.userAgentPresetFFmpeg ?? 'FFmpeg'}: $userAgent';
      case 'android_chrome':
        return '${strings?.userAgentPresetAndroid ?? 'Android Chrome'}: ${userAgent.substring(0, 50)}...';
      case 'ios_safari':
        return '${strings?.userAgentPresetIOS ?? 'iOS Safari'}: ${userAgent.substring(0, 50)}...';
    }
  }
  // Custom user agent
  if (userAgent.length > 60) {
    return '${AppStrings.of(context)?.userAgentPresetCustom ?? 'Custom'}: ${userAgent.substring(0, 60)}...';
  }
  return '${AppStrings.of(context)?.userAgentPresetCustom ?? 'Custom'}: $userAgent';
}

String seekStepLabel(BuildContext context, int seconds) {
  final strings = AppStrings.of(context);
  switch (seconds) {
    case 5:
      return strings?.seekStep5s ?? '5秒';
    case 10:
      return strings?.seekStep10s ?? '10秒';
    case 30:
      return strings?.seekStep30s ?? '30秒';
    case 60:
      return strings?.seekStep60s ?? '60秒';
    case 120:
      return strings?.seekStep120s ?? '120秒';
    default:
      return '$seconds秒';
  }
}

String volumeBoostDescription(BuildContext context, int db) {
  final strings = AppStrings.of(context);
  if (db <= -10) return strings?.volumeBoostLow ?? 'Significantly lower volume';
  if (db < 0) return strings?.volumeBoostSlightLow ?? 'Slightly lower volume';
  if (db == 0) return strings?.volumeBoostNormal ?? 'Keep original volume';
  if (db <= 10) {
    return strings?.volumeBoostSlightHigh ?? 'Slightly higher volume';
  }
  return strings?.volumeBoostHigh ?? 'Significantly higher volume';
}

String homeFontSizeLabel(BuildContext context, SettingsProvider settings) {
  final percent = (settings.homeFontScale * 100).round();
  if (percent == 100) return '$percent%（默认）';
  return '$percent%';
}

String themeModeLabel(BuildContext context, String mode) {
  final strings = AppStrings.of(context);
  switch (mode) {
    case 'light':
      return strings?.themeLight ?? 'Light';
    case 'dark':
      return strings?.themeDark ?? 'Dark';
    case 'system':
    default:
      return strings?.themeSystem ?? 'Follow System';
  }
}

String logLevelLabel(BuildContext context, String level) {
  final strings = AppStrings.of(context);
  switch (level) {
    case 'debug':
      return strings?.logLevelDebug ?? 'Debug';
    case 'release':
      return strings?.logLevelRelease ?? 'Release';
    case 'off':
      return strings?.logLevelOff ?? 'Off';
    default:
      return level;
  }
}

String logLevelDescription(BuildContext context, String level) {
  final strings = AppStrings.of(context);
  switch (level) {
    case 'debug':
      return strings?.logLevelDebugDesc ??
          'Log everything for development and debugging';
    case 'release':
      return strings?.logLevelReleaseDesc ??
          'Only log warnings and errors (recommended)';
    case 'off':
      return strings?.logLevelOffDesc ?? 'Do not log anything';
    default:
      return '';
  }
}

String screenPositionLabel(BuildContext context, int position) {
  final strings = AppStrings.of(context);
  switch (position) {
    case 1:
      return strings?.screenPosition1 ?? 'Top Left (1)';
    case 2:
      return strings?.screenPosition2 ?? 'Top Right (2)';
    case 3:
      return strings?.screenPosition3 ?? 'Bottom Left (3)';
    case 4:
    default:
      return strings?.screenPosition4 ?? 'Bottom Right (4)';
  }
}

String fontFamilyLabel(
    BuildContext context, String fontFamily, SettingsProvider settings) {
  // 获取当前语言代码，如果设置为跟随系统则使用系统语言
  final languageCode = settings.locale?.languageCode ??
      WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  final isChinese = languageCode.startsWith('zh');

  switch (fontFamily) {
    case 'System':
      return isChinese ? '系统字体' : 'System Font';
    // 中文字体
    case 'Microsoft YaHei':
      return isChinese ? '微软雅黑' : 'Microsoft YaHei';
    case 'SimHei':
      return isChinese ? '黑体' : 'SimHei';
    case 'SimSun':
      return isChinese ? '宋体' : 'SimSun';
    case 'KaiTi':
      return isChinese ? '楷体' : 'KaiTi';
    case 'FangSong':
      return isChinese ? '仿宋' : 'FangSong';
    // 英文字体
    case 'Arial':
      return 'Arial';
    case 'Calibri':
      return 'Calibri';
    case 'Georgia':
      return 'Georgia';
    case 'Verdana':
      return 'Verdana';
    case 'Tahoma':
      return 'Tahoma';
    case 'Times New Roman':
      return 'Times New Roman';
    case 'Segoe UI':
      return 'Segoe UI';
    case 'Impact':
      return 'Impact';
    default:
      return fontFamily;
  }
}

String pageTransitionLabel(BuildContext context, String animation) {
  final strings = AppStrings.of(context);
  switch (animation) {
    case 'fade':
      return strings?.transitionFade ?? 'Fade';
    case 'slide':
      return strings?.transitionSlide ?? 'Slide';
    case 'scale':
      return strings?.transitionScale ?? 'Scale';
    case 'none':
      return strings?.transitionNone ?? 'None';
    case 'material':
      return strings?.transitionMaterial ?? 'Material (Android)';
    case 'cupertino':
      return strings?.transitionCupertino ?? 'Cupertino (iOS)';
    default:
      return strings?.transitionFade ?? 'Fade';
  }
}

String orientationLabel(BuildContext context, String orientation) {
  switch (orientation) {
    case 'portrait':
      return '竖屏';
    case 'landscape':
      return '横屏';
    case 'auto':
    default:
      return '自动旋转';
  }
}

String logoCacheDaysLabel(BuildContext context, int days) {
  final strings = AppStrings.of(context);
  if (days <= 0) return strings?.logoCacheDaysNever ?? 'Never expire';
  if (days == 1) return '1 ${strings?.day ?? 'day'}';
  return '$days ${strings?.days ?? 'days'}';
}

String logoCacheMaxObjectsLabel(BuildContext context, int count) {
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(count % 1000 == 0 ? 0 : 1)}k ${AppStrings.of(context)?.items ?? 'items'}';
  }
  return '$count ${AppStrings.of(context)?.items ?? 'items'}';
}

String logoCacheDaysHint(BuildContext context, int days) {
  final strings = AppStrings.of(context);
  switch (days) {
    case 1:
      return strings?.logoCacheDaysHint1 ??
          'Minimal storage, fresh logos daily';
    case 3:
      return strings?.logoCacheDaysHint3 ??
          'Small storage, good for weekly updates';
    case 14:
      return strings?.logoCacheDaysHint14 ?? 'Less re-downloads, more storage';
    case 30:
      return strings?.logoCacheDaysHint30 ?? 'Monthly refresh, larger cache';
    case 60:
      return strings?.logoCacheDaysHint60 ?? 'Bi-monthly, large cache';
    case 90:
      return strings?.logoCacheDaysHint90 ?? 'Quarterly, maximum cache';
    case 7:
    default:
      return strings?.logoCacheDaysHint7 ?? 'Balanced (recommended)';
  }
}

String logoCacheMaxObjectsHint(BuildContext context, int count) {
  final strings = AppStrings.of(context);
  const estKbPerLogo = 50; // ~50KB per logo average
  final estMb = (count * estKbPerLogo / 1024).toStringAsFixed(0);
  switch (count) {
    case 200:
      return '${strings?.logoCacheHintSmall ?? 'Small'} (~${estMb}MB)';
    case 1000:
      return '${strings?.logoCacheHintLarge ?? 'Large'} (~${estMb}MB)';
    case 2000:
      return '${strings?.logoCacheHintXLarge ?? 'Very large'} (~${estMb}MB)';
    case 5000:
      return '${strings?.logoCacheHintMax ?? 'Maximum'} (~${estMb}MB)';
    case 500:
    default:
      return '${strings?.logoCacheHintBalanced ?? 'Balanced (recommended)'} (~${estMb}MB)';
  }
}
