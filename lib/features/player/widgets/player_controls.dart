import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/platform/windows_pip_channel.dart';
import '../../favorites/providers/favorites_provider.dart';
import '../../settings/providers/dlna_provider.dart';

import '../../epg/providers/epg_provider.dart';
import '../../../core/services/epg_service.dart';
import '../providers/player_provider.dart';
import '../../../core/widgets/tv_focusable.dart';


class PlayerControls extends StatelessWidget {
  final String channelName;
  final bool isFullScreen;
  final VoidCallback onBackPressed;
  final VoidCallback onSettingsPressed;
  final VoidCallback onFullScreenToggle;
  final VoidCallback onMultiScreenToggle;
  final Function(PlayerProvider) onSourceSwitched;
  final void Function(EpgProgram program)? onPlayCatchup;

  const PlayerControls({
    super.key,
    required this.channelName,
    required this.isFullScreen,
    required this.onBackPressed,
    required this.onSettingsPressed,
    required this.onFullScreenToggle,
    required this.onMultiScreenToggle,
    required this.onSourceSwitched,
    this.onPlayCatchup,
  });


  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top gradient mask
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 160,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xCC000000), // 80% black
                  Color(0x66000000), // 40% black
                  Colors.transparent,
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        // Bottom gradient mask
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 200,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0x80000000), // 50% black
                  Color(0xE6000000), // 90% black
                ],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),
        ),
        // Content
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopBar(context),
              const Spacer(),
              _buildBottomControls(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Semi-transparent channel logo/back button
          TVFocusable(
            onSelect: onBackPressed,
            focusScale: 1.0,
            showFocusBorder: false,
            builder: (context, isFocused, child) {
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isFocused
                      ? AppTheme.getPrimaryColor(context)
                      : const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isFocused
                        ? AppTheme.getPrimaryColor(context)
                        : const Color(0x1AFFFFFF),
                    width: isFocused ? 2 : 1,
                  ),
                ),
                child: child,
              );
            },
            child: const Icon(Icons.arrow_back_rounded,
                color: Colors.white, size: 18),
          ),

          const SizedBox(width: 16),

          // Minimal channel info
          Expanded(
            child: Consumer<PlayerProvider>(
              builder: (context, provider, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      provider.currentChannel?.name ?? channelName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Live indicator
                        if (provider.state == PlayerState.playing) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: AppTheme.getGradient(context),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle,
                                    color: Colors.white, size: 6),
                                SizedBox(width: 4),
                                Text('LIVE',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // Source indicator (if multiple sources)
                        if (provider.currentChannel != null &&
                            provider.currentChannel!.hasMultipleSources) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.getPrimaryColor(context)
                                  .withOpacity(0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.swap_horiz,
                                    color: Colors.white, size: 10),
                                const SizedBox(width: 4),
                                Text(
                                  '${AppStrings.of(context)?.source ?? 'Source'} ${provider.currentSourceIndex}/${provider.sourceCount}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // Video info
                        if (provider.videoInfo.isNotEmpty)
                          Text(
                            provider.videoInfo,
                            style: const TextStyle(
                                color: Color(0x99FFFFFF), fontSize: 11),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),

          // Favorite button - minimal style
          Consumer<FavoritesProvider>(
            builder: (context, favorites, _) {
              final playerProvider = context.read<PlayerProvider>();
              final currentChannel = playerProvider.currentChannel;
              final isFav = currentChannel != null &&
                  favorites.isFavorite(currentChannel.id ?? 0);

              return TVFocusable(
                onSelect: () async {
                  if (currentChannel != null) {
                    final success =
                        await favorites.toggleFavorite(currentChannel);
                    if (success && context.mounted) {
                      final newIsFav =
                          favorites.isFavorite(currentChannel.id ?? 0);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            newIsFav ? '已添加到收藏' : '已从收藏中移除',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  }
                },
                focusScale: 1.0,
                showFocusBorder: false,
                builder: (context, isFocused, child) {
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: isFav ? AppTheme.getGradient(context) : null,
                      color: isFav
                          ? null
                          : (isFocused
                              ? AppTheme.getPrimaryColor(context)
                              : const Color(0x33FFFFFF)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isFocused
                            ? AppTheme.getPrimaryColor(context)
                            : const Color(0x1AFFFFFF),
                        width: isFocused ? 2 : 1,
                      ),
                    ),
                    child: child,
                  );
                },
                child: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              );
            },
          ),

          // PiP 迷你播放器按钮 - 仅 Windows
          if (WindowsPipChannel.isSupported) ...[
            const SizedBox(width: 8),
            _buildPipButton(context),
          ],

          // 分屏模式按钮 - 仅桌面平台
          if (PlatformDetector.isDesktop) ...[
            const SizedBox(width: 8),
            _buildMultiScreenButton(context),
          ],
        ],
      ),
    );
  }

  Widget _buildMultiScreenButton(BuildContext context) {
    return TVFocusable(
      onSelect: onMultiScreenToggle,
      focusScale: 1.0,
      showFocusBorder: false,
      builder: (context, isFocused, child) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isFocused
                ? AppTheme.getPrimaryColor(context)
                : const Color(0x33FFFFFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFocused
                  ? AppTheme.getPrimaryColor(context)
                  : const Color(0x1AFFFFFF),
              width: isFocused ? 2 : 1,
            ),
          ),
          child: child,
        );
      },
      child: const Icon(
        Icons.grid_view_rounded,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  Widget _buildPipButton(BuildContext context) {
    final isInPip = WindowsPipChannel.isInPipMode;
    final isPinned = WindowsPipChannel.isPinned;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // PiP 切换按钮
        TVFocusable(
          onSelect: () async {
            await WindowsPipChannel.togglePipMode();
            onFullScreenToggle(); // Trigger state update in parent
          },
          focusScale: 1.0,
          showFocusBorder: false,
          builder: (context, isFocused, child) {
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: isInPip ? AppTheme.getGradient(context) : null,
                color: isInPip
                    ? null
                    : (isFocused
                        ? AppTheme.getPrimaryColor(context)
                        : const Color(0x33FFFFFF)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isFocused
                      ? AppTheme.getPrimaryColor(context)
                      : const Color(0x1AFFFFFF),
                  width: isFocused ? 2 : 1,
                ),
              ),
              child: child,
            );
          },
          child: Icon(
            isInPip ? Icons.fullscreen : Icons.picture_in_picture_alt,
            color: Colors.white,
            size: 18,
          ),
        ),
        // 置顶按钮 - 仅在迷你模式下显示
        if (isInPip) ...[
          const SizedBox(width: 8),
          TVFocusable(
            onSelect: () async {
              await WindowsPipChannel.togglePin();
              // Parent should probably refresh if they are watching this, but WindowsPipChannel usually handles its own state
            },
            focusScale: 1.0,
            showFocusBorder: false,
            builder: (context, isFocused, child) {
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: isPinned ? AppTheme.getGradient(context) : null,
                  color: isPinned
                      ? null
                      : (isFocused
                          ? AppTheme.getPrimaryColor(context)
                          : const Color(0x33FFFFFF)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isFocused
                        ? AppTheme.getPrimaryColor(context)
                        : const Color(0x1AFFFFFF),
                    width: isFocused ? 2 : 1,
                  ),
                ),
                child: child,
              );
            },
            child: Icon(
              isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: Colors.white,
              size: 18,
            ),
          ),
        ],
      ],
    );
  }

  void _showEpgSheet(BuildContext context, PlayerProvider provider) {

    final channel = provider.currentChannel;
    if (channel == null) return;
    final epgProvider = context.read<EpgProvider>();
    final programs = epgProvider.getProgramsInTimeRange(
      channel.epgId,
      channel.name,
      8,
      daysBefore: 5,
      daysAfter: 2,
    );

    // 按 +0800 的自然日分组
    final Map<String, List<EpgProgram>> grouped = {};
    for (final p in programs) {
      final local = p.start.add(const Duration(hours: 8));
      final key = DateFormat('yyyy-MM-dd').format(DateTime(local.year, local.month, local.day));
      grouped.putIfAbsent(key, () => []).add(p);
    }
    final dates = grouped.keys.toList()..sort();
    final nowLocal = DateTime.now().toUtc().add(const Duration(hours: 8));
    final todayKey = DateFormat('yyyy-MM-dd')
        .format(DateTime(nowLocal.year, nowLocal.month, nowLocal.day));
    String selectedDate = dates.contains(todayKey)
        ? todayKey
        : (dates.isNotEmpty ? dates.first : '');
    final scrollController = ScrollController();
    final dateScrollController = ScrollController();
    bool hasScrolled = false;


    void performScroll() {
      if (!scrollController.hasClients || selectedDate.isEmpty) {
        print('❌ Scroll failed: hasClients=${scrollController.hasClients}, selectedDate=$selectedDate');
        return;
      }
      
      final dayPrograms = List<EpgProgram>.from(grouped[selectedDate] ?? [])
        ..sort((a, b) => a.start.compareTo(b.start));
      if (dayPrograms.isEmpty) {
        print('❌ No programs for date: $selectedDate');
        return;
      }
      
      final nowUtc = DateTime.now().toUtc();
      final idx = dayPrograms.indexWhere((p) => nowUtc.isAfter(p.start) && nowUtc.isBefore(p.end));
      
      print('📺 Total programs: ${dayPrograms.length}, Current idx: $idx');
      
      if (idx >= 0) {
        hasScrolled = true;
        const listVisibleHeight = 369.0;
        
        final maxScroll = scrollController.position.maxScrollExtent;
        final totalContentHeight = maxScroll + listVisibleHeight;
        
        // 根据实际内容高度和节目数量计算平均item高度
        final avgItemHeight = totalContentHeight / dayPrograms.length;
        
        // 计算当前节目的中心位置
        final programCenter = idx * avgItemHeight + avgItemHeight / 2;
        
        // 计算目标偏移：让节目中心对齐可视区域中心
        final targetOffset = programCenter - (listVisibleHeight / 2);
        final clampedOffset = targetOffset.clamp(0.0, maxScroll);
        
        print('📊 Programs=${dayPrograms.length}, idx=$idx, avgHeight=${avgItemHeight.toStringAsFixed(1)}');
        print('📊 ProgramCenter=${programCenter.toStringAsFixed(1)}, target=${targetOffset.toStringAsFixed(1)}, clamped=${clampedOffset.toStringAsFixed(1)}');
        
        try {
          scrollController.jumpTo(clampedOffset);
          print('✅ Scroll completed - program should be centered');
        } catch (e) {
          print('❌ Scroll error: $e');
        }
      } else {
        print('⚠️ Current program not found');
      }
    }

    void scrollToCurrent() {
      if (hasScrolled) {
        print('⚠️ Already scrolled, skipping');
        return;
      }
      print('⏳ Scheduling scroll in 300ms...');
      Future.delayed(const Duration(milliseconds: 300), () {
        performScroll();
      });
    }











    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.5),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // 使用单次触发确保只滚动一次
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!hasScrolled) {
                scrollToCurrent();
              }
            });
            return SafeArea(
              child: SizedBox(
                height: 500,
                child: Column(
                  children: [
                    // 标题栏 - 带左右margin
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              channel.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Text(
                            '+0800',
                            style: TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 日期列表 - 全宽，只有左padding，右侧可以自由滚动
                    if (dates.isNotEmpty)
                      SizedBox(
                        height: 45,
                        child: ListView.separated(
                          controller: dateScrollController,
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(left: 32, right: 80),
                          itemCount: dates.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final dateKey = dates[index];
                            final dateLabel = DateFormat('MM-dd').format(DateTime.parse(dateKey));
                            final isSelected = dateKey == selectedDate;
                            return ChoiceChip(
                              label: Text(
                                dateLabel,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : const Color(0xCCFFFFFF),
                                  fontSize: 12,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (_) {
                                setModalState(() {
                                  selectedDate = dateKey;
                                  hasScrolled = false;
                                });
                              },
                              selectedColor: AppTheme.getPrimaryColor(context),
                              backgroundColor: const Color(0x33000000),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    // 节目列表 - 带左右margin的Container
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(16),
                        child: programs.isEmpty
                            ? const Center(
                                child: Text(
                                  'EPG 暂无数据',
                                  style: TextStyle(color: Color(0x99FFFFFF)),
                                ),
                              )
                            : ListView(
                                controller: scrollController,
                                children: selectedDate.isEmpty
                                    ? []
                                    : () {
                                        final dayPrograms = List<EpgProgram>.from(grouped[selectedDate] ?? [])
                                          ..sort((a, b) => a.start.compareTo(b.start));
                                        if (dayPrograms.isEmpty) return <Widget>[];
                                        final nowUtc = DateTime.now().toUtc();
                                        final EpgProgram activeProgram = dayPrograms.firstWhere(
                                          (p) => nowUtc.isAfter(p.start) && nowUtc.isBefore(p.end),
                                          orElse: () => dayPrograms.first,
                                        );
                                        return dayPrograms.map((program) {
                                          final canReplay = (channel.catchupSource?.isNotEmpty ?? false) && program.end.isBefore(nowUtc);
                                          final isNow = identical(activeProgram, program);
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 10),
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: isNow ? AppTheme.getPrimaryColor(context).withOpacity(0.12) : const Color(0x15000000),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isNow
                                                    ? AppTheme.getPrimaryColor(context)
                                                    : const Color(0x22FFFFFF),
                                                width: isNow ? 1.2 : 0.8,
                                              ),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                SizedBox(
                                                  width: 150,
                                                  child: Text(
                                                    '${DateFormat('yyyy-MM-dd HH:mm').format(program.start.add(const Duration(hours: 8)))}\n${DateFormat('yyyy-MM-dd HH:mm').format(program.end.add(const Duration(hours: 8)))}',
                                                    style: TextStyle(
                                                      color: isNow ? AppTheme.getPrimaryColor(context) : const Color(0xCCFFFFFF),
                                                      fontSize: 12,
                                                      height: 1.4,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          if (isNow)
                                                            Container(
                                                              margin: const EdgeInsets.only(right: 6),
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: AppTheme.getPrimaryColor(context),
                                                                borderRadius: BorderRadius.circular(6),
                                                              ),
                                                              child: const Text(
                                                                '正在播放',
                                                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                              ),
                                                            ),
                                                          Expanded(
                                                            child: Text(
                                                              program.title,
                                                              style: TextStyle(
                                                                color: isNow ? Colors.white : const Color(0xEEFFFFFF),
                                                                fontSize: 14,
                                                                fontWeight: isNow ? FontWeight.w700 : FontWeight.w600,
                                                              ),
                                                              maxLines: 2,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (program.description != null && program.description!.isNotEmpty)
                                                        Padding(
                                                          padding: const EdgeInsets.only(top: 4),
                                                          child: Text(
                                                            program.description!,
                                                            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      if (canReplay)
                                                        Padding(
                                                          padding: const EdgeInsets.only(top: 6),
                                                          child: ElevatedButton(
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: AppTheme.getPrimaryColor(context),
                                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                            ),
                                                            onPressed: () {
                                                              Navigator.of(context).pop();
                                                              onPlayCatchup?.call(program);
                                                            },
                                                            child: const Text('回放'),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList();
                                      }(),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }





  Widget _buildBottomControls(BuildContext context) {

    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // EPG 当前节目和下一个节目
              Consumer<EpgProvider>(
                builder: (context, epgProvider, _) {
                  final channel = provider.currentChannel;
                  final currentProgram = epgProvider.getCurrentProgram(
                      channel?.epgId, channel?.name);
                  final nextProgram =
                      epgProvider.getNextProgram(channel?.epgId, channel?.name);

                  if (currentProgram != null || nextProgram != null) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () => _showEpgSheet(context, provider),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0x33000000),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (currentProgram != null)
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.getPrimaryColor(context),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                          AppStrings.of(context)?.nowPlaying ??
                                              'Now playing',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        currentProgram.title,
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      (AppStrings.of(context)?.endsInMinutes ??
                                              'Ends in {minutes} min')
                                          .replaceFirst('{minutes}',
                                              '${currentProgram.remainingMinutes}'),
                                      style: const TextStyle(
                                          color: Color(0x99FFFFFF), fontSize: 11),
                                    ),
                                  ],
                                ),
                              if (nextProgram != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppTheme.getPrimaryColor(context)
                                                .withOpacity(0.7),
                                            AppTheme.getSecondaryColor(context)
                                                .withOpacity(0.7),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                          AppStrings.of(context)?.upNext ??
                                              'Up next',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        nextProgram.title,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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

                  return const SizedBox.shrink();
                },
              ),

              // Control buttons row (moved above progress bar)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Volume control
                  _buildVolumeControl(context, provider),

                  const SizedBox(width: 16),

                  // 手机端源切换按钮 - 上一个源
                  if (PlatformDetector.isMobile &&
                      provider.currentChannel != null &&
                      provider.currentChannel!.hasMultipleSources)
                    TVFocusable(
                      onSelect: () {
                        provider.switchToPreviousSource();
                        onSourceSwitched(provider);
                      },
                      focusScale: 1.0,
                      showFocusBorder: false,
                      builder: (context, isFocused, child) {
                        return Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isFocused
                                ? AppTheme.getPrimaryColor(context)
                                : const Color(0x33FFFFFF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isFocused
                                  ? AppTheme.getPrimaryColor(context)
                                  : const Color(0x1AFFFFFF),
                              width: isFocused ? 2 : 1,
                            ),
                          ),
                          child: child,
                        );
                      },
                      child: const Icon(Icons.skip_previous_rounded,
                          color: Colors.white, size: 18),
                    ),

                  if (PlatformDetector.isMobile &&
                      provider.currentChannel != null &&
                      provider.currentChannel!.hasMultipleSources)
                    const SizedBox(width: 8),

                  // Play/Pause - Lotus gradient button (smaller)
                  TVFocusable(
                    autofocus: true,
                    onSelect: provider.togglePlayPause,
                    focusScale: 1.0,
                    showFocusBorder: false,
                    builder: (context, isFocused, child) {
                      return Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: AppTheme.getGradient(context),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                isFocused ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.getPrimaryColor(context)
                                  .withAlpha(isFocused ? 100 : 50),
                              blurRadius: isFocused ? 16 : 8,
                              spreadRadius: isFocused ? 2 : 1,
                            ),
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: Icon(
                      provider.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),

                  // 手机端源切换按钮 - 下一个源
                  if (PlatformDetector.isMobile &&
                      provider.currentChannel != null &&
                      provider.currentChannel!.hasMultipleSources)
                    const SizedBox(width: 8),

                  if (PlatformDetector.isMobile &&
                      provider.currentChannel != null &&
                      provider.currentChannel!.hasMultipleSources)
                    TVFocusable(
                      onSelect: () {
                        provider.switchToNextSource();
                        onSourceSwitched(provider);
                      },
                      focusScale: 1.0,
                      showFocusBorder: false,
                      builder: (context, isFocused, child) {
                        return Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isFocused
                                ? AppTheme.getPrimaryColor(context)
                                : const Color(0x33FFFFFF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isFocused
                                  ? AppTheme.getPrimaryColor(context)
                                  : const Color(0x1AFFFFFF),
                              width: isFocused ? 2 : 1,
                            ),
                          ),
                          child: child,
                        );
                      },
                      child: const Icon(Icons.skip_next_rounded,
                          color: Colors.white, size: 18),
                    ),

                  const SizedBox(width: 16),

                  // Settings button (smaller)
                  TVFocusable(
                    onSelect: onSettingsPressed,
                    focusScale: 1.0,
                    showFocusBorder: false,
                    builder: (context, isFocused, child) {
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isFocused
                              ? AppTheme.getPrimaryColor(context)
                              : const Color(0x33FFFFFF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isFocused
                                ? AppTheme.getPrimaryColor(context)
                                : const Color(0x1AFFFFFF),
                            width: isFocused ? 2 : 1,
                          ),
                        ),
                        child: child,
                      );
                    },
                    child: const Icon(Icons.settings_rounded,
                        color: Colors.white, size: 18),
                  ),

                  // Windows 全屏按钮
                  if (PlatformDetector.isWindows) ...[
                    const SizedBox(width: 16),
                    TVFocusable(
                      onSelect: onFullScreenToggle,
                      focusScale: 1.0,
                      showFocusBorder: false,
                      builder: (context, isFocused, child) {
                        return Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isFocused
                                ? AppTheme.getPrimaryColor(context)
                                : const Color(0x33FFFFFF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isFocused
                                  ? AppTheme.getPrimaryColor(context)
                                  : const Color(0x1AFFFFFF),
                              width: isFocused ? 2 : 1,
                            ),
                          ),
                          child: child,
                        );
                      },
                      child: Icon(
                          isFullScreen
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                          color: Colors.white,
                          size: 18),
                    ),
                  ],
                ],
              ),

              // Slim progress bar at bottom (显示有时长的流，包括回放 HLS)
              Consumer<DlnaProvider>(
                builder: (context, dlnaProvider, _) {
                  final showProgressBar = provider.duration.inSeconds > 0;
                  if (!showProgressBar) return const SizedBox.shrink();



                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      children: [
                        // 时间显示
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(provider.position),
                              style: const TextStyle(
                                  color: Color(0x99FFFFFF), fontSize: 11),
                            ),
                            Text(
                              _formatDuration(provider.duration),
                              style: const TextStyle(
                                  color: Color(0x99FFFFFF), fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 4),
                            overlayShape:
                                const RoundSliderOverlayShape(overlayRadius: 8),
                            activeTrackColor: AppTheme.getPrimaryColor(context),
                            inactiveTrackColor: const Color(0x33FFFFFF),
                            thumbColor: AppTheme.getPrimaryColor(context),
                          ),
                          child: Slider(
                            value: provider.position.inSeconds.toDouble().clamp(
                                0, provider.duration.inSeconds.toDouble()),
                            max: provider.duration.inSeconds.toDouble(),
                            onChanged: (value) =>
                                provider.seek(Duration(seconds: value.toInt())),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Keyboard hints
              if (PlatformDetector.useDPadNavigation)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    AppStrings.of(context)?.playerHintTV ??
                        '↑↓ Switch Channel · ← Categories · OK Play/Pause',
                    style:
                        const TextStyle(color: Color(0x66FFFFFF), fontSize: 11),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVolumeControl(BuildContext context, PlayerProvider provider) {
    // 确保音量值在 0-1 范围内
    final volume = provider.volume.clamp(0.0, 1.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TVFocusable(
          onSelect: provider.toggleMute,
          focusScale: 1.0,
          showFocusBorder: false,
          builder: (context, isFocused, child) {
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isFocused
                    ? AppTheme.getPrimaryColor(context)
                    : const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isFocused
                      ? AppTheme.getPrimaryColor(context)
                      : const Color(0x1AFFFFFF),
                  width: isFocused ? 2 : 1,
                ),
              ),
              child: child,
            );
          },
          child: Icon(
            provider.isMuted || volume == 0
                ? Icons.volume_off_rounded
                : volume < 0.5
                    ? Icons.volume_down_rounded
                    : Icons.volume_up_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 70,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
            ),
            child: Slider(
              value: provider.isMuted ? 0 : volume,
              onChanged: (value) {
                // 如果当前是静音状态，拖动滑块时先取消静音
                if (provider.isMuted && value > 0) {
                  provider.toggleMute();
                }
                provider.setVolume(value);
              },
              activeColor: AppTheme.getPrimaryColor(context),
              inactiveColor: const Color(0x33FFFFFF),
            ),
          ),
        ),
      ],
    );
  }
}
