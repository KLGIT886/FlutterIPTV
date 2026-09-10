import 'package:material_ui/material_ui.dart';

import 'color_scheme_data.dart';
import 'color_scheme_manager.dart';
import 'app_theme.dart';

// ============ Dynamic Theme Generation with Color Schemes ============

extension AppThemeDynamic on AppTheme {
  /// 根据配色方案 ID 生成黑暗主题
  static ThemeData getDarkTheme(String schemeId, [String? fontFamily]) {
    final scheme = ColorSchemeManager.instance.getDarkScheme(schemeId);
    // ServiceLocator.log.d('AppTheme: 生成黑暗主题 - schemeId=$schemeId, primaryColor=${scheme.primaryColor}, secondaryColor=${scheme.secondaryColor}, fontFamily=$fontFamily');
    return _buildDarkTheme(scheme, fontFamily);
  }
  
  /// 根据配色方案 ID 生成明亮主题
  static ThemeData getLightTheme(String schemeId, [String? fontFamily]) {
    final scheme = ColorSchemeManager.instance.getLightScheme(schemeId);
    // ServiceLocator.log.d('AppTheme: 生成明亮主题 - schemeId=$schemeId, primaryColor=${scheme.primaryColor}, secondaryColor=${scheme.secondaryColor}, fontFamily=$fontFamily');
    return _buildLightTheme(scheme, fontFamily);
  }
  
  /// 构建黑暗主题（使用配色方案）
  static ThemeData _buildDarkTheme(ColorSchemeData scheme, [String? fontFamily]) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: scheme.primaryColor,
      scaffoldBackgroundColor: AppTheme.backgroundColorDark,
      fontFamily: fontFamily,
      hoverColor: scheme.primaryColor.withOpacity(0.08),
      focusColor: scheme.primaryColor.withOpacity(0.12),
      highlightColor: scheme.primaryColor.withOpacity(0.1),
      splashColor: scheme.primaryColor.withOpacity(0.12),
      colorScheme: ColorScheme.dark(
        primary: scheme.primaryColor,
        secondary: scheme.secondaryColor,
        surface: AppTheme.surfaceColorDark,
        error: AppTheme.errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppTheme.textPrimaryDark,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: AppTheme.cardColorDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppTheme.textPrimaryDark),
        titleTextStyle: TextStyle(
          color: AppTheme.textPrimaryDark,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppTheme.surfaceColorDark,
        selectedItemColor: scheme.primaryColor,
        unselectedItemColor: AppTheme.textMutedDark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      iconTheme: const IconThemeData(
        color: AppTheme.textSecondaryDark,
        size: 24,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark, letterSpacing: -0.5),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark, letterSpacing: -0.25),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryDark),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryDark),
        titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryDark),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: AppTheme.textPrimaryDark),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: AppTheme.textSecondaryDark),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: AppTheme.textMutedDark),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryDark),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryDark),
        labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppTheme.textMutedDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primaryColor,
          side: BorderSide(color: scheme.primaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTheme.glassColorDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: const BorderSide(color: AppTheme.glassBorderColorDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: const BorderSide(color: AppTheme.glassBorderColorDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide(color: scheme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: const BorderSide(color: AppTheme.errorColor),
        ),
        hintStyle: const TextStyle(color: AppTheme.textMutedDark),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppTheme.cardColorDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        elevation: 8,
        shadowColor: Colors.black54,
      ),
      listTileTheme: ListTileThemeData(
        selectedTileColor: scheme.primaryColor.withOpacity(0.1),
        selectedColor: scheme.primaryColor,
        iconColor: AppTheme.textSecondaryDark,
        textColor: AppTheme.textPrimaryDark,
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppTheme.cardColorDark,
        contentTextStyle: const TextStyle(color: AppTheme.textPrimaryDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF1F1F1F),
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primaryColor),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primaryColor,
        inactiveTrackColor: AppTheme.glassColorDark,
        thumbColor: scheme.primaryColor,
        overlayColor: scheme.primaryColor.withAlpha(51),
        trackHeight: 4,
      ),
    );
  }
  
  /// 构建明亮主题（使用配色方案）
  static ThemeData _buildLightTheme(ColorSchemeData scheme, [String? fontFamily]) {
    final bgColor = scheme.backgroundColor ?? AppTheme.backgroundColorLight;
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: scheme.primaryColor,
      scaffoldBackgroundColor: bgColor,
      fontFamily: fontFamily,
      hoverColor: scheme.primaryColor.withOpacity(0.12),
      focusColor: scheme.primaryColor.withOpacity(0.15),
      highlightColor: scheme.primaryColor.withOpacity(0.15),
      splashColor: scheme.primaryColor.withOpacity(0.2),
      colorScheme: ColorScheme.light(
        primary: scheme.primaryColor,
        secondary: scheme.secondaryColor,
        surface: AppTheme.surfaceColorLight,
        error: AppTheme.errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppTheme.textPrimaryLight,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: AppTheme.cardColorLight,
        elevation: 1,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTheme.surfaceColorLight,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppTheme.textPrimaryLight),
        titleTextStyle: TextStyle(
          color: AppTheme.textPrimaryLight,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppTheme.surfaceColorLight,
        selectedItemColor: scheme.primaryColor,
        unselectedItemColor: AppTheme.textMutedLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      iconTheme: const IconThemeData(
        color: AppTheme.textSecondaryLight,
        size: 24,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryLight),
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryLight),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryLight),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryLight),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryLight),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryLight),
        titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryLight),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: AppTheme.textPrimaryLight),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: AppTheme.textSecondaryLight),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: AppTheme.textMutedLight),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryLight),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryLight),
        labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppTheme.textMutedLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primaryColor,
          side: BorderSide(color: scheme.primaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTheme.glassColorLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: const BorderSide(color: AppTheme.glassBorderColorLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: const BorderSide(color: AppTheme.glassBorderColorLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide(color: scheme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: const BorderSide(color: AppTheme.errorColor),
        ),
        hintStyle: const TextStyle(color: AppTheme.textMutedLight),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppTheme.cardColorLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        elevation: 8,
        shadowColor: Colors.black26,
      ),
      listTileTheme: ListTileThemeData(
        selectedTileColor: scheme.primaryColor.withOpacity(0.15),
        selectedColor: scheme.primaryColor,
        iconColor: AppTheme.textSecondaryLight,
        textColor: AppTheme.textPrimaryLight,
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppTheme.cardColorLight,
        contentTextStyle: const TextStyle(color: AppTheme.textPrimaryLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE0E0E0),
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primaryColor),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primaryColor,
        inactiveTrackColor: AppTheme.glassColorLight,
        thumbColor: scheme.primaryColor,
        overlayColor: scheme.primaryColor.withAlpha(51),
        trackHeight: 4,
      ),
    );
  }
}
