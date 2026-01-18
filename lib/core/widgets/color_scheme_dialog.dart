import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/color_scheme_data.dart';
import '../theme/color_scheme_manager.dart';
import '../i18n/app_strings.dart';
import '../../features/settings/providers/settings_provider.dart';
import 'color_scheme_card.dart';
import 'custom_color_picker_dialog.dart';
import 'tv_focusable.dart';

/// 配色方案选择对话框
/// 根据当前主题模式显示对应的配色列表
class ColorSchemeDialog extends StatefulWidget {
  const ColorSchemeDialog({super.key});

  @override
  State<ColorSchemeDialog> createState() => _ColorSchemeDialogState();
}

class _ColorSchemeDialogState extends State<ColorSchemeDialog> {
  final _manager = ColorSchemeManager.instance;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final strings = AppStrings.of(context);
    
    // 根据当前主题模式判断是黑暗还是明亮
    final isDarkMode = _isDarkMode(context, settings);
    final schemes = isDarkMode 
        ? _manager.getAllDarkSchemes() 
        : _manager.getAllLightSchemes();
    final currentSchemeId = isDarkMode 
        ? settings.darkColorScheme 
        : settings.lightColorScheme;

    return Dialog(
      backgroundColor: AppTheme.getSurfaceColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings?.selectColorScheme ?? 'Select Color Scheme',
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TVFocusable(
                  onSelect: () => Navigator.pop(context),
                  focusScale: 1.0,
                  showFocusBorder: false,
                  builder: (context, isFocused, child) {
                    return Container(
                      decoration: BoxDecoration(
                        color: isFocused 
                            ? AppTheme.getFocusBackgroundColor(context) 
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: child,
                    );
                  },
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    color: AppTheme.getTextMuted(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // 配色方案网格
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                ),
                itemCount: schemes.length,
                itemBuilder: (context, index) {
                  final scheme = schemes[index];
                  final isSelected = scheme.id == currentSchemeId;
                  
                  return ColorSchemeCard(
                    scheme: scheme,
                    isSelected: isSelected,
                    onTap: () => _onSchemeSelected(context, scheme, isDarkMode),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 自定义颜色按钮
            TVFocusable(
              onSelect: () => _showCustomColorPicker(context),
              focusScale: 1.0,
              showFocusBorder: false,
              builder: (context, isFocused, child) {
                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isFocused 
                          ? AppTheme.getPrimaryColor(context).withOpacity(0.8)
                          : AppTheme.getPrimaryColor(context),
                      width: isFocused ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: child,
                );
              },
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showCustomColorPicker(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.palette_rounded,
                          color: AppTheme.getPrimaryColor(context),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          strings?.customColorPicker ?? 'Custom Color Picker',
                          style: TextStyle(
                            color: AppTheme.getPrimaryColor(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示自定义颜色选择器
  Future<void> _showCustomColorPicker(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => const CustomColorPickerDialog(),
    );
  }

  /// 判断当前是否为黑暗模式
  bool _isDarkMode(BuildContext context, SettingsProvider settings) {
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

  /// 处理配色方案选择
  void _onSchemeSelected(BuildContext context, ColorSchemeData scheme, bool isDarkMode) {
    final settings = context.read<SettingsProvider>();
    final strings = AppStrings.of(context);
    
    // 根据模式调用对应的设置方法
    if (isDarkMode) {
      settings.setDarkColorScheme(scheme.id);
    } else {
      settings.setLightColorScheme(scheme.id);
    }
    
    // 关闭对话框
    Navigator.pop(context);
    
    // 显示成功提示
    final schemeName = _getSchemeName(context, scheme);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          (strings?.colorSchemeChanged ?? 'Color scheme changed to: {scheme}')
              .replaceFirst('{scheme}', schemeName),
        ),
        backgroundColor: AppTheme.successColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 获取配色方案名称
  String _getSchemeName(BuildContext context, ColorSchemeData scheme) {
    final strings = AppStrings.of(context);
    
    // 检查是否为自定义颜色
    if (scheme.id.startsWith('custom_')) {
      return strings?.colorSchemeCustom ?? 'Custom';
    }
    
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
}
