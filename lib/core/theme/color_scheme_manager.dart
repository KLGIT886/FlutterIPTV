import 'package:flutter/material.dart';
import 'color_scheme_data.dart';

/// 配色方案管理器
/// 单例模式，管理所有可用的配色方案
class ColorSchemeManager {
  // 单例实例
  static final ColorSchemeManager instance = ColorSchemeManager._();
  
  ColorSchemeManager._();
  
  // ============ 黑暗模式配色方案列表 ============
  static const List<ColorSchemeData> darkSchemes = [
    darkLotus,
    darkOcean,
    darkForest,
    darkSunset,
    darkLavender,
    darkMidnight,
  ];
  
  // ============ 明亮模式配色方案列表 ============
  static const List<ColorSchemeData> lightSchemes = [
    lightLotus,
    lightSky,
    lightSpring,
    lightCoral,
    lightViolet,
    lightClassic,
  ];
  
  /// 根据 ID 获取黑暗模式配色方案
  /// 如果找不到，返回默认的 Lotus 配色
  /// 支持自定义颜色格式: custom_AARRGGBB
  ColorSchemeData getDarkScheme(String id) {
    // 检查是否为自定义颜色
    if (id.startsWith('custom_')) {
      return _createCustomScheme(id, isDark: true);
    }
    
    try {
      return darkSchemes.firstWhere((scheme) => scheme.id == id);
    } catch (_) {
      // 找不到时返回默认配色
      return darkLotus;
    }
  }
  
  /// 根据 ID 获取明亮模式配色方案
  /// 如果找不到，返回默认的 Lotus Light 配色
  /// 支持自定义颜色格式: custom_AARRGGBB
  ColorSchemeData getLightScheme(String id) {
    // 检查是否为自定义颜色
    if (id.startsWith('custom_')) {
      return _createCustomScheme(id, isDark: false);
    }
    
    try {
      return lightSchemes.firstWhere((scheme) => scheme.id == id);
    } catch (_) {
      // 找不到时返回默认配色
      return lightLotus;
    }
  }
  
  /// 从自定义颜色ID创建配色方案
  /// ID格式: custom_AARRGGBB (例如: custom_ffe91e63)
  ColorSchemeData _createCustomScheme(String id, {required bool isDark}) {
    try {
      // 提取颜色值
      final colorHex = id.substring(7); // 移除 "custom_" 前缀
      final colorValue = int.parse(colorHex, radix: 16);
      final primaryColor = Color(colorValue);
      
      // 生成渐变色（稍微调整色相）
      final hsl = HSLColor.fromColor(primaryColor);
      final secondaryColor = hsl.withHue((hsl.hue + 20) % 360).toColor();
      
      return ColorSchemeData(
        id: id,
        nameKey: 'colorSchemeCustom',
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
        backgroundColor: isDark ? null : const Color(0xFFF5F5F5),
        descriptionKey: 'colorSchemeCustom',
      );
    } catch (e) {
      // 解析失败时返回默认配色
      return isDark ? darkLotus : lightLotus;
    }
  }
  
  /// 获取所有黑暗模式配色方案
  List<ColorSchemeData> getAllDarkSchemes() {
    return darkSchemes;
  }
  
  /// 获取所有明亮模式配色方案
  List<ColorSchemeData> getAllLightSchemes() {
    return lightSchemes;
  }
  
  /// 检查配色方案 ID 是否有效（黑暗模式）
  bool isDarkSchemeValid(String id) {
    return darkSchemes.any((scheme) => scheme.id == id);
  }
  
  /// 检查配色方案 ID 是否有效（明亮模式）
  bool isLightSchemeValid(String id) {
    return lightSchemes.any((scheme) => scheme.id == id);
  }
}
