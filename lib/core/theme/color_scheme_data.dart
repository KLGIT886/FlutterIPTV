import 'package:material_ui/material_ui.dart';

/// 配色方案数据模型
/// 定义单个配色方案的所有颜色信息
class ColorSchemeData {
  /// 唯一标识符，如 'lotus', 'ocean'
  final String id;
  
  /// 国际化键，如 'colorSchemeLotus'
  final String nameKey;
  
  /// 主色1（渐变起始色）
  final Color primaryColor;
  
  /// 主色2（渐变结束色）
  final Color secondaryColor;
  
  /// 背景色（仅明亮模式需要）
  final Color? backgroundColor;
  
  /// 特点描述的国际化键
  final String descriptionKey;
  
  const ColorSchemeData({
    required this.id,
    required this.nameKey,
    required this.primaryColor,
    required this.secondaryColor,
    this.backgroundColor,
    required this.descriptionKey,
  });
  
  /// 获取渐变色
  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, secondaryColor],
  );
  
  /// 获取焦点色（通常是主色1）
  Color get focusColor => primaryColor;
  
  /// 获取焦点边框色（主色1的亮色版本）
  Color get focusBorderColor {
    final hsl = HSLColor.fromColor(primaryColor);
    return hsl.withLightness((hsl.lightness + 0.2).clamp(0.0, 1.0)).toColor();
  }
  
  /// 获取柔和渐变（40% 透明度）
  LinearGradient get softGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryColor.withOpacity(0.4),
      secondaryColor.withOpacity(0.4),
    ],
  );
}


// ============ 黑暗模式配色方案 ============

/// Lotus（莲花）- 粉紫渐变，优雅现代的品牌色
const darkLotus = ColorSchemeData(
  id: 'lotus',
  nameKey: 'colorSchemeLotus',
  primaryColor: Color(0xFFE91E8C),
  secondaryColor: Color(0xFF9C27B0),
  descriptionKey: 'colorSchemeDescLotus',
);

/// Ocean（海洋）- 蓝色渐变，冷静专业护眼
const darkOcean = ColorSchemeData(
  id: 'ocean',
  nameKey: 'colorSchemeOcean',
  primaryColor: Color(0xFF0EA5E9),
  secondaryColor: Color(0xFF0284C7),
  descriptionKey: 'colorSchemeDescOcean',
);

/// Forest（森林）- 绿色渐变，自然舒适护眼
const darkForest = ColorSchemeData(
  id: 'forest',
  nameKey: 'colorSchemeForest',
  primaryColor: Color(0xFF10B981),
  secondaryColor: Color(0xFF059669),
  descriptionKey: 'colorSchemeDescForest',
);

/// Sunset（日落）- 橙红渐变，温暖活力醒目
const darkSunset = ColorSchemeData(
  id: 'sunset',
  nameKey: 'colorSchemeSunset',
  primaryColor: Color(0xFFF97316),
  secondaryColor: Color(0xFFDC2626),
  descriptionKey: 'colorSchemeDescSunset',
);

/// Lavender（薰衣草）- 紫色渐变，神秘高贵柔和
const darkLavender = ColorSchemeData(
  id: 'lavender',
  nameKey: 'colorSchemeLavender',
  primaryColor: Color(0xFF8B5CF6),
  secondaryColor: Color(0xFF6D28D9),
  descriptionKey: 'colorSchemeDescLavender',
);

/// Midnight（午夜）- 深蓝渐变，深邃专注低调
const darkMidnight = ColorSchemeData(
  id: 'midnight',
  nameKey: 'colorSchemeMidnight',
  primaryColor: Color(0xFF1E40AF),
  secondaryColor: Color(0xFF1E3A8A),
  descriptionKey: 'colorSchemeDescMidnight',
);

// ============ 明亮模式配色方案 ============

/// Lotus Light（莲花亮色）- 粉紫渐变 + 浅灰白背景
const lightLotus = ColorSchemeData(
  id: 'lotus-light',
  nameKey: 'colorSchemeLotusLight',
  primaryColor: Color(0xFFDB2777),
  secondaryColor: Color(0xFF7C3AED),
  backgroundColor: Color(0xFFF5F5F5),
  descriptionKey: 'colorSchemeDescLotusLight',
);

/// Sky（天空）- 天蓝渐变 + 浅蓝白背景
const lightSky = ColorSchemeData(
  id: 'sky',
  nameKey: 'colorSchemeSky',
  primaryColor: Color(0xFF0284C7),
  secondaryColor: Color(0xFF0369A1),
  backgroundColor: Color(0xFFF0F9FF),
  descriptionKey: 'colorSchemeDescSky',
);

/// Spring（春天）- 草绿渐变 + 浅绿白背景
const lightSpring = ColorSchemeData(
  id: 'spring',
  nameKey: 'colorSchemeSpring',
  primaryColor: Color(0xFF059669),
  secondaryColor: Color(0xFF047857),
  backgroundColor: Color(0xFFF0FDF4),
  descriptionKey: 'colorSchemeDescSpring',
);

/// Coral（珊瑚）- 珊瑚橙渐变 + 浅橙白背景
const lightCoral = ColorSchemeData(
  id: 'coral',
  nameKey: 'colorSchemeCoral',
  primaryColor: Color(0xFFEA580C),
  secondaryColor: Color(0xFFC2410C),
  backgroundColor: Color(0xFFFFF7ED),
  descriptionKey: 'colorSchemeDescCoral',
);

/// Violet（紫罗兰）- 紫罗兰渐变 + 浅紫白背景
const lightViolet = ColorSchemeData(
  id: 'violet',
  nameKey: 'colorSchemeViolet',
  primaryColor: Color(0xFF7C3AED),
  secondaryColor: Color(0xFF6D28D9),
  backgroundColor: Color(0xFFFAF5FF),
  descriptionKey: 'colorSchemeDescViolet',
);

/// Classic（经典）- 灰蓝渐变 + 纯白背景
const lightClassic = ColorSchemeData(
  id: 'classic',
  nameKey: 'colorSchemeClassic',
  primaryColor: Color(0xFF475569),
  secondaryColor: Color(0xFF334155),
  backgroundColor: Color(0xFFFFFFFF),
  descriptionKey: 'colorSchemeDescClassic',
);
