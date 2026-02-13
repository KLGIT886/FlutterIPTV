import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../epg/providers/epg_provider.dart';
import '../../../core/services/epg_service.dart';
import '../../player/providers/player_provider.dart';
import '../../../core/models/channel.dart';

class EpgScreen extends StatefulWidget {
  final String? channelId;
  final String? channelName;
  final Channel? channel; // 完整的Channel对象，用于回放功能
  final EpgProgram? catchupProgram; // 当前回放的节目（用于定位）

  const EpgScreen({
    super.key,
    this.channelId,
    this.channelName,
    this.channel,
    this.catchupProgram,
  });

  @override
  State<EpgScreen> createState() => _EpgScreenState();
}

class _EpgScreenState extends State<EpgScreen> {
  // 时区偏移：+8 表示东八区（北京时间）
  static const int timeZoneOffset = 8;
  // 时间范围：前5天，后2天
  static const int daysBefore = 5;
  static const int daysAfter = 2;

  // 当前选中的日期索引（daysBefore表示今天）
  int _selectedDayIndex = daysBefore; // 默认选中今天

  // 滚动控制器
  final ScrollController _scrollController = ScrollController();

  // 是否已滚动到当前节目
  bool _hasScrolledToCurrentProgram = false;

  @override
  void initState() {
    super.initState();
    if (widget.catchupProgram != null) {
      _selectDateForCatchupProgram();
    }
  }

  /// 选择回放节目所在的日期
  void _selectDateForCatchupProgram() {
    final program = widget.catchupProgram;
    if (program == null) return;

    // 获取回放节目在目标时区的日期
    final programDate = program.startInTimeZone(timeZoneOffset);
    final programDay = DateTime(programDate.year, programDate.month, programDate.day);

    // 获取今天的日期
    final now = _getLocalNow();
    final today = DateTime(now.year, now.month, now.day);

    // 计算日期索引
    final daysDiff = programDay.difference(today).inDays;
    final targetIndex = daysBefore + daysDiff;

    // 确保索引在有效范围内
    if (targetIndex >= 0 && targetIndex <= daysBefore + daysAfter) {
      _selectedDayIndex = targetIndex;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 滚动到当前正在播放的节目（或回放节目）
  void _scrollToCurrentProgram(List<EpgProgram> programs) {
    if (_hasScrolledToCurrentProgram || programs.isEmpty) return;

    int targetIndex = -1;

    // 优先级1：如果有回放节目，定位到回放节目
    if (widget.catchupProgram != null) {
      for (int i = 0; i < programs.length; i++) {
        if (programs[i].start.millisecondsSinceEpoch == widget.catchupProgram!.start.millisecondsSinceEpoch &&
            programs[i].title == widget.catchupProgram!.title) {
          targetIndex = i;
          break;
        }
      }
    }

    // 优先级2：找到当前正在播放的节目索引
    if (targetIndex == -1) {
      for (int i = 0; i < programs.length; i++) {
        if (programs[i].isNowInTimeZone(timeZoneOffset)) {
          targetIndex = i;
          break;
        }
      }
    }

    // 优先级3：如果没找到正在播放的，找下一个节目
    if (targetIndex == -1) {
      for (int i = 0; i < programs.length; i++) {
        if (programs[i].isNextInTimeZone(timeZoneOffset)) {
          targetIndex = i;
          break;
        }
      }
    }

    // 优先级4：如果今天没有当前/下一个节目，找最近的已播放节目
    if (targetIndex == -1) {
      for (int i = programs.length - 1; i >= 0; i--) {
        if (programs[i].isPastInTimeZone(timeZoneOffset)) {
          targetIndex = i;
          break;
        }
      }
    }

    _hasScrolledToCurrentProgram = true;

    // 滚动到目标位置
    if (targetIndex >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && mounted) {
          const itemHeight = 88.0;
          const topPadding = 16.0;
          final offset = targetIndex * itemHeight + topPadding;
          final maxScroll = _scrollController.position.maxScrollExtent;
          final clampedOffset = offset.clamp(0.0, maxScroll);

          _scrollController.animateTo(
            clampedOffset,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  /// 切换日期时重置滚动状态
  void _onDaySelected(int index) {
    if (_selectedDayIndex == index) return;
    setState(() {
      _selectedDayIndex = index;
      _hasScrolledToCurrentProgram = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [
                    AppTheme.getBackgroundColor(context),
                    AppTheme.getPrimaryColor(context).withOpacity(0.15),
                    AppTheme.getBackgroundColor(context),
                  ]
                : [
                    AppTheme.getBackgroundColor(context),
                    AppTheme.getBackgroundColor(context).withOpacity(0.9),
                    AppTheme.getPrimaryColor(context).withOpacity(0.08),
                  ],
          ),
        ),
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              title: Text(
                widget.channelName ?? '节目指南',
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                // 回放模式下显示"回到直播"按钮
                if (widget.catchupProgram != null)
                  TextButton.icon(
                    onPressed: () {
                      // 返回并播放直播
                      final playerProvider = context.read<PlayerProvider>();
                      final channel = widget.channel;
                      if (channel != null) {
                        playerProvider.playChannel(channel);
                      }
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.live_tv, size: 18),
                    label: const Text('回到直播', style: TextStyle(fontSize: 14)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.getPrimaryColor(context),
                      backgroundColor: AppTheme.getPrimaryColor(context).withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: AppTheme.getTextSecondary(context)),
                      const SizedBox(width: 4),
                      Text(
                        'GMT+8',
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _buildDaySelector(),
            Expanded(
              child: Consumer<EpgProvider>(
                builder: (context, epgProvider, _) {
                  if (epgProvider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!epgProvider.hasData) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 64, color: AppTheme.getTextMuted(context)),
                          const SizedBox(height: 16),
                          Text(
                            '暂无EPG数据',
                            style: TextStyle(
                              color: AppTheme.getTextSecondary(context),
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '请检查EPG设置或网络连接',
                            style: TextStyle(
                              color: AppTheme.getTextMuted(context),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // 获取选中日期的节目
                  final selectedDate = _getSelectedDate();
                  final programs = epgProvider.getProgramsForDate(
                    widget.channelId,
                    widget.channelName,
                    selectedDate,
                    timeZoneOffset,
                  );

                  if (programs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today, size: 64, color: AppTheme.getTextMuted(context)),
                          const SizedBox(height: 16),
                          Text(
                            '该日期无节目',
                            style: TextStyle(
                              color: AppTheme.getTextSecondary(context),
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatDateDisplay(selectedDate),
                            style: TextStyle(
                              color: AppTheme.getTextMuted(context),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // 自动滚动到当前节目
                  if (!_hasScrolledToCurrentProgram) {
                    _scrollToCurrentProgram(programs);
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: programs.length,
                    itemBuilder: (context, index) {
                      final program = programs[index];
                      return _buildProgramCard(program, epgProvider);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 获取当前时区的本地时间
  DateTime _getLocalNow() {
    // 先转UTC，再加时区偏移，确保无论设备时区如何都能正确计算
    return DateTime.now().toUtc().add(Duration(hours: timeZoneOffset));
  }

  /// 构建日期选择器
  Widget _buildDaySelector() {
    final now = _getLocalNow();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: daysBefore + daysAfter + 1,
        itemBuilder: (context, index) {
          final date = today.subtract(Duration(days: daysBefore - index));
          final isSelected = index == _selectedDayIndex;
          final isToday = index == daysBefore;
          final weekday = ['一', '二', '三', '四', '五', '六', '日'][date.weekday - 1];

          return GestureDetector(
            onTap: () => _onDaySelected(index),
            child: Container(
              width: 56,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                gradient: isSelected ? AppTheme.getGradient(context) : null,
                color: isSelected ? null : AppTheme.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isToday && !isSelected
                      ? AppTheme.getPrimaryColor(context)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.getTextPrimary(context),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isToday ? '今天' : '周$weekday',
                    style: TextStyle(
                      color: isSelected ? Colors.white.withOpacity(0.9) : AppTheme.getTextSecondary(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 获取选中的日期
  DateTime _getSelectedDate() {
    final now = _getLocalNow();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: daysBefore - _selectedDayIndex));
  }

  Widget _buildProgramCard(EpgProgram program, EpgProvider epgProvider) {
    final localStart = program.startInTimeZone(timeZoneOffset);
    final localEnd = program.endInTimeZone(timeZoneOffset);
    final duration = localEnd.difference(localStart);
    
    // 判断节目状态
    final isNow = program.isNowInTimeZone(timeZoneOffset);
    final isNext = program.isNextInTimeZone(timeZoneOffset);
    final isPast = program.isPastInTimeZone(timeZoneOffset);
    
    // 回放模式：检查当前节目是否是回放的节目
    final isCatchupMode = widget.catchupProgram != null;
    final isCatchupProgram = isCatchupMode &&
        program.start.millisecondsSinceEpoch == widget.catchupProgram!.start.millisecondsSinceEpoch &&
        program.title == widget.catchupProgram!.title;

    // 检查是否支持回放（回放模式下仍然可以播放其他节目）
    final canReplay = isPast && widget.channel?.catchupSource != null && widget.channel!.catchupSource!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCatchupProgram
              ? AppTheme.warningColor  // 回放节目用橙色边框
              : (isNow && !isCatchupMode)
                  ? AppTheme.successColor  // 直播节目用绿色边框
                  : isNext
                      ? AppTheme.getPrimaryColor(context).withOpacity(0.5)
                      : AppTheme.getGlassBorderColor(context),
          width: (isCatchupProgram || (isNow && !isCatchupMode)) ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    program.title,
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCatchupProgram)
                  // 回放中标签
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.replay, size: 12, color: AppTheme.warningColor),
                        const SizedBox(width: 4),
                        Text(
                          '回放中',
                          style: TextStyle(
                            color: AppTheme.warningColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isNow && !isCatchupMode)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.play_circle_filled, size: 12, color: AppTheme.successColor),
                        const SizedBox(width: 4),
                        Text(
                          '正在播放',
                          style: TextStyle(
                            color: AppTheme.successColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isNext && !isCatchupMode)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.getPrimaryColor(context).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, size: 12, color: AppTheme.getPrimaryColor(context)),
                        const SizedBox(width: 4),
                        Text(
                          '即将播放',
                          style: TextStyle(
                            color: AppTheme.getPrimaryColor(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isPast && canReplay)
                  // 回放按钮
                  GestureDetector(
                    onTap: () => _playCatchup(program),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.getPrimaryColor(context).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.replay, size: 12, color: AppTheme.getPrimaryColor(context)),
                          const SizedBox(width: 4),
                          Text(
                            '回放',
                            style: TextStyle(
                              color: AppTheme.getPrimaryColor(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: AppTheme.getTextSecondary(context)),
                const SizedBox(width: 6),
                Text(
                  '${_formatDateTime(localStart)} - ${_formatTime(localEnd)}',
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.timer, size: 14, color: AppTheme.getTextSecondary(context)),
                const SizedBox(width: 6),
                Text(
                  _formatDuration(duration),
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            if (program.description != null && program.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  program.description!,
                  style: TextStyle(
                    color: AppTheme.getTextMuted(context),
                    fontSize: 13,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (program.category != null && program.category!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.getSurfaceColor(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        program.category!,
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 格式化UTC时间戳 (用于回放URL)
  String _formatUtcTimestamp(DateTime time) {
    return '${time.toUtc().toIso8601String().split('.').first}Z';
  }

  /// 播放回放
  Future<void> _playCatchup(EpgProgram program) async {
    final provider = context.read<PlayerProvider>();
    final channel = widget.channel;
    if (channel == null) return;

    final template = channel.catchupSource;
    if (template == null || template.isEmpty) return;

    final start = _formatUtcTimestamp(program.start);
    final end = _formatUtcTimestamp(program.end);

    final playbackUrl = template
        .replaceAll(r'${start}', start)
        .replaceAll(r'${end}', end);

    // 返回播放器界面并播放回放
    Navigator.pop(context);
    await provider.playCatchup(channel, playbackUrl, program: program);
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateDisplay(DateTime date) {
    final now = _getLocalNow();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));

    final dateOnly = DateTime(date.year, date.month, date.day);

    String prefix;
    if (dateOnly == today) {
      prefix = '今天';
    } else if (dateOnly == yesterday) {
      prefix = '昨天';
    } else if (dateOnly == tomorrow) {
      prefix = '明天';
    } else {
      prefix = '${date.month}月${date.day}日';
    }

    return '$prefix ${_formatDate(date)}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}小时${duration.inMinutes % 60}分钟';
    } else {
      return '${duration.inMinutes}分钟';
    }
  }
}
