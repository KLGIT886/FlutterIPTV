import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/player_provider.dart';

class PlayerSettingsSheet extends StatelessWidget {
  const PlayerSettingsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const PlayerSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.of(context)?.playbackSettings ?? 'Playback Settings',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.of(context)?.playbackSpeed ?? 'Playback Speed',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                  final isSelected = provider.playbackSpeed == speed;
                  return ChoiceChip(
                    label: Text('${speed}x'),
                    selected: isSelected,
                    onSelected: (_) => provider.setPlaybackSpeed(speed),
                    selectedColor: AppTheme.getPrimaryColor(context),
                    backgroundColor: AppTheme.cardColor,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
