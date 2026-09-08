import 'package:material_ui/material_ui.dart';

import '../../../core/i18n/app_strings.dart';

/// 手势指示浮层：音量/亮度/频道切换时屏幕中央的提示。
///
/// 通过 [gestureType]（'volume'/'brightness'/'channel'）与 [gestureValue] 决定
/// 图标与文本；[gestureType] 为空时渲染空占位。
class GestureOverlay extends StatelessWidget {
  /// 手势类型：'volume'、'brightness'、'channel'、'horizontal' 或 null。
  final String? gestureType;

  /// 手势值（-1.0 ~ 1.0 或 0 ~ 1.0，依类型而定）。
  final double gestureValue;

  const GestureOverlay({
    super.key,
    required this.gestureType,
    required this.gestureValue,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String label;

    if (gestureType == 'volume') {
      icon = gestureValue > 0.5
          ? Icons.volume_up
          : (gestureValue > 0 ? Icons.volume_down : Icons.volume_off);
      label = '${(gestureValue * 100).toInt()}%';
    } else if (gestureType == 'brightness') {
      icon = gestureValue > 0.5 ? Icons.brightness_high : Icons.brightness_low;
      label = '${(gestureValue * 100).toInt()}%';
    } else if (gestureType == 'channel') {
      // 频道切换指示
      if (gestureValue < 0) {
        icon = Icons.keyboard_arrow_up;
        label = AppStrings.of(context)?.nextChannel ?? 'Next channel';
      } else {
        icon = Icons.keyboard_arrow_down;
        label = AppStrings.of(context)?.previousChannel ?? 'Previous channel';
      }
    } else {
      return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(180),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 36),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}