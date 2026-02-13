import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../i18n/app_strings.dart';
import '../../features/settings/providers/settings_provider.dart';
import 'tv_focusable.dart';
import '../services/service_locator.dart';

/// 自定义颜色选择器对话框
/// 允许用户通过调色板选择自定义主题颜色
class CustomColorPickerDialog extends StatefulWidget {
  const CustomColorPickerDialog({super.key});

  @override
  State<CustomColorPickerDialog> createState() => _CustomColorPickerDialogState();
}

class _CustomColorPickerDialogState extends State<CustomColorPickerDialog> {
  Color _selectedColor = const Color(0xFFB39DDB); // 默认淡紫色
  final FocusNode _firstColorFocusNode = FocusNode();
  
  @override
  void initState() {
    super.initState();
    
    // 读取当前配色方案，如果是自定义颜色则初始化为该颜色
    _loadCurrentCustomColor();
    
    // 延迟请求焦点，确保对话框完全构建后再设置焦点
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _firstColorFocusNode.requestFocus();
      }
    });
  }
  
  /// 加载当前自定义颜色（如果有）
  void _loadCurrentCustomColor() {
    final settings = context.read<SettingsProvider>();
    
    // 根据当前主题模式获取配色方案ID
    final isDarkMode = _isDarkMode(context, settings);
    final currentSchemeId = isDarkMode 
        ? settings.darkColorScheme 
        : settings.lightColorScheme;
    
    // 检查是否为自定义颜色
    if (currentSchemeId.startsWith('custom_')) {
      try {
        // 提取颜色值: custom_AARRGGBB
        final colorHex = currentSchemeId.substring(7); // 移除 "custom_" 前缀
        final colorValue = int.parse(colorHex, radix: 16);
        _selectedColor = Color(colorValue);
      } catch (e) {
        // 解析失败时保持默认颜色
        ServiceLocator.log.d('Failed to parse custom color: $e');
      }
    }
  }
  
  @override
  void dispose() {
    _firstColorFocusNode.dispose();
    super.dispose();
  }
  
  // 预设颜色调色板 - 淡雅柔和色系
  static const List<Color> _presetColors = [
    // 第一行：淡粉紫色系
    Color(0xFFF8BBD0), // 淡粉
    Color(0xFFF48FB1),
    Color(0xFFE1BEE7), // 淡紫
    Color(0xFFCE93D8),
    Color(0xFFD1C4E9), // 淡薰衣草
    Color(0xFFB39DDB),
    
    // 第二行：淡蓝色系
    Color(0xFFBBDEFB), // 淡蓝
    Color(0xFF90CAF9),
    Color(0xFFB3E5FC), // 淡天蓝
    Color(0xFF81D4FA),
    Color(0xFFB2EBF2), // 淡青
    Color(0xFF80DEEA),
    
    // 第三行：淡绿色系
    Color(0xFFC8E6C9), // 淡绿
    Color(0xFFA5D6A7),
    Color(0xFFB2DFDB), // 淡青绿
    Color(0xFF80CBC4),
    Color(0xFFDCEDC8), // 淡黄绿
    Color(0xFFC5E1A5),
    
    // 第四行：淡黄橙色系
    Color(0xFFFFF9C4), // 淡黄
    Color(0xFFFFF59D),
    Color(0xFFFFECB3), // 淡琥珀
    Color(0xFFFFE082),
    Color(0xFFFFE0B2), // 淡橙
    Color(0xFFFFCC80),
    
    // 第五行：淡暖色系
    Color(0xFFFFCCBC), // 淡深橙
    Color(0xFFFFAB91),
    Color(0xFFFFCDD2), // 淡红
    Color(0xFFEF9A9A),
    Color(0xFFF8BBD0), // 淡粉红
    Color(0xFFF48FB1),
    
    // 第六行：淡灰色系
    Color(0xFFCFD8DC), // 淡蓝灰
    Color(0xFFB0BEC5),
    Color(0xFFE0E0E0), // 淡灰
    Color(0xFFBDBDBD),
    Color(0xFFEEEEEE), // 浅灰
    Color(0xFFF5F5F5),
  ];

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        // 返回键直接关闭，不应用颜色
      },
      child: Dialog(
        backgroundColor: AppTheme.getSurfaceColor(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 550),
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
                      strings?.customColorPicker ?? 'Custom Color Picker',
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
              
              // 当前选中颜色预览
              _buildColorPreview(),
              const SizedBox(height: 24),
              
              // 颜色调色板
              Expanded(
                child: _buildColorPalette(),
              ),
              
              const SizedBox(height: 16),
              
              // 提示文字
              Center(
                child: Text(
                  '按 OK 应用颜色 · 按返回键取消',
                  style: TextStyle(
                    color: AppTheme.getTextMuted(context),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建颜色预览区域
  Widget _buildColorPreview() {
    return Container(
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(
        color: _selectedColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _selectedColor.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppStrings.of(context)?.selectedColor ?? 'Selected Color',
              style: TextStyle(
                color: _getContrastColor(_selectedColor),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '#${_selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
              style: TextStyle(
                color: _getContrastColor(_selectedColor),
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建颜色调色板
  Widget _buildColorPalette() {
    return FocusTraversalGroup(
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemCount: _presetColors.length,
        itemBuilder: (context, index) {
          final color = _presetColors[index];
          final isSelected = color.value == _selectedColor.value;
          
          return TVFocusable(
            focusNode: index == 0 ? _firstColorFocusNode : null,
            autofocus: index == 0,
            onSelect: () {
              // 按OK键直接应用颜色
              setState(() {
                _selectedColor = color;
              });
              _applyColor(context);
            },
            focusScale: 1.0,
            showFocusBorder: false,
            builder: (context, isFocused, child) {
              // 根据颜色亮度决定边框颜色
              final isLightColor = _isLightColor(color);
              final borderColor = isLightColor ? Colors.black : Colors.white;
              
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected 
                        ? borderColor
                        : isFocused
                            ? borderColor.withOpacity(0.8)
                            : Colors.transparent,
                    width: isSelected ? 3 : isFocused ? 2 : 1,
                  ),
                  boxShadow: [
                    if (isFocused || isSelected)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: isFocused ? 16 : 12,
                        spreadRadius: isFocused ? 3 : 2,
                      ),
                  ],
                ),
                child: child,
              );
            },
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedColor = color;
                  });
                  _applyColor(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: Center(
                  child: isSelected
                      ? Icon(
                          Icons.check_rounded,
                          color: _getContrastColor(color),
                          size: 28,
                        )
                      : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 判断颜色是否为浅色
  bool _isLightColor(Color color) {
    final luminance = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return luminance > 0.7; // 阈值提高到0.7，更准确地判断浅色
  }

  /// 应用选中的颜色
  void _applyColor(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final strings = AppStrings.of(context);
    
    // 创建自定义配色方案ID
    final customSchemeId = 'custom_${_selectedColor.value.toRadixString(16)}';
    
    // 根据当前主题模式保存
    final isDarkMode = _isDarkMode(context, settings);
    if (isDarkMode) {
      settings.setDarkColorScheme(customSchemeId);
    } else {
      settings.setLightColorScheme(customSchemeId);
    }
    
    // 关闭自定义颜色选择器对话框
    Navigator.pop(context);
    
    // 延迟一下再关闭配色方案对话框，确保第一个对话框已经关闭
    Future.delayed(const Duration(milliseconds: 100), () {
      if (context.mounted) {
        // 关闭配色方案对话框
        Navigator.pop(context);
        
        // 显示成功提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings?.customColorApplied ?? 'Custom color applied',
            ),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  /// 判断当前是否为黑暗模式
  bool _isDarkMode(BuildContext context, SettingsProvider settings) {
    if (settings.themeMode == 'dark') {
      return true;
    } else if (settings.themeMode == 'light') {
      return false;
    } else {
      final brightness = MediaQuery.of(context).platformBrightness;
      return brightness == Brightness.dark;
    }
  }

  /// 获取对比色（用于文字显示）
  Color _getContrastColor(Color color) {
    // 计算亮度
    final luminance = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
