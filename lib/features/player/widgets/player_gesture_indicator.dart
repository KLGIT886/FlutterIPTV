import 'package:flutter/material.dart';
import '../../../core/i18n/app_strings.dart';

class PlayerGestureIndicator extends StatelessWidget {
  final String gestureType; // 'volume', 'brightness', 'channel'
  final double value;

  const PlayerGestureIndicator({
    super.key,
    required this.gestureType,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String label;

    if (gestureType == 'volume') {
      icon = value > 0.5
          ? Icons.volume_up
          : (value > 0 ? Icons.volume_down : Icons.volume_off);
      label = '${(value * 100).toInt()}%';
    } else if (gestureType == 'brightness') {
      icon = value > 0.5 ? Icons.brightness_high : Icons.brightness_low;
      label = '${(value * 100).toInt()}%';
    } else if (gestureType == 'channel') {
      // 频道切换指示
      if (value < 0) {
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
