import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/auto_scroll_text.dart';
import '../../../core/services/epg_service.dart';
import '../providers/multi_screen_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../epg/providers/epg_provider.dart';

/// 分屏单元内的叠加层：显示频道名与当前节目名（可自动滚动）。
class ChannelNameOverlay extends StatelessWidget {
  final ScreenPlayerState screen;
  final double nameWidth;
  final bool forceAutoScroll;

  const ChannelNameOverlay({
    super.key,
    required this.screen,
    required this.nameWidth,
    required this.forceAutoScroll,
  });

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.read<SettingsProvider>();

    // 如果配置为不显示频道名称，则返回空数组
    if (!settingsProvider.showMultiScreenChannelName) {
      return const SizedBox.shrink();
    }

    // 使用 select 只监听当前屏幕频道的 EPG 数据
    final currentProgram = screen.channel != null
        ? context.select<EpgProvider, EpgProgram?>(
            (provider) => provider.getCurrentProgram(
              screen.channel!.epgId,
              screen.channel!.name,
            ),
          )
        : null;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: nameWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AutoScrollText(
                key: ValueKey('ch_${screen.channel?.id}'),
                text: screen.channel?.name ?? '',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
                scrollSpeed: 30.0,
                scrollDelay: const Duration(milliseconds: 1000),
                textAlign: TextAlign.left,
                forceScroll: forceAutoScroll,
              ),
              if (currentProgram != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.play_circle_filled,
                        color: AppTheme.getPrimaryColor(context), size: 10),
                    const SizedBox(width: 4),
                    Expanded(
                      child: AutoScrollText(
                        key: ValueKey('pg_${currentProgram.title}'),
                        text: currentProgram.title,
                        style: TextStyle(
                            color: AppTheme.getPrimaryColor(context),
                            fontSize: 10),
                        scrollSpeed: 30.0,
                        scrollDelay: const Duration(milliseconds: 1000),
                        textAlign: TextAlign.left,
                        forceScroll: forceAutoScroll,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
