import 'package:material_ui/material_ui.dart';
import '../theme/app_theme.dart';
import '../theme/color_scheme_data.dart';
import '../i18n/app_strings.dart';
import 'tv_focusable.dart';

/// 配色方案卡片组件
/// 显示单个配色方案的预览和名称
class ColorSchemeCard extends StatelessWidget {
  final ColorSchemeData scheme;
  final bool isSelected;
  final VoidCallback onTap;

  const ColorSchemeCard({
    super.key,
    required this.scheme,
    required this.isSelected,
    required this.onTap,
  });

  String _getColorSchemeName(BuildContext context) {
    final strings = AppStrings.of(context);
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

  @override
  Widget build(BuildContext context) {
    return TVFocusable(
      onSelect: onTap,
      focusScale: 1.0,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return AnimatedContainer(
          duration: AppTheme.animationFast,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Colors.white
                  : (isFocused ? scheme.primaryColor : Colors.transparent),
              width: isSelected ? 3 : (isFocused ? 2 : 0),
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: scheme.primaryColor.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            gradient: scheme.gradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 渐变色预览区域（占70%）
              const Spacer(flex: 7),
              
              // 名称和选中指示器区域（占30%）
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _getColorSchemeName(context),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
