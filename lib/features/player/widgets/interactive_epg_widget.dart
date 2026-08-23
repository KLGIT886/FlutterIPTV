import 'dart:ui' as ui;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/models/channel.dart';
import '../../../core/services/epg_service.dart';
import '../../epg/providers/epg_provider.dart';
import '../../../core/theme/app_theme.dart';

class InteractiveEpgWidget extends StatefulWidget {
  final Channel channel;
  final Function(EpgProgram) onProgramSelected;
  final VoidCallback onBackToLive;
  final bool isPlayingCatchup;
  final EpgProgram? currentCatchupProgram;

  const InteractiveEpgWidget({
    super.key,
    required this.channel,
    required this.onProgramSelected,
    required this.onBackToLive,
    this.isPlayingCatchup = false,
    this.currentCatchupProgram,
  });

  @override
  State<InteractiveEpgWidget> createState() => _InteractiveEpgWidgetState();
}

class _InteractiveEpgWidgetState extends State<InteractiveEpgWidget> {
  late DateTime _selectedDate;
  final ScrollController _dateScrollController = ScrollController();
  final ScrollController _programScrollController = ScrollController();
  final List<GlobalKey> _itemKeys = [];
  bool _hasInitialScrolled = false;
  bool _autoAdjustedDate = false;

  @override
  void initState() {
    super.initState();
    // If playing catchup, use the catchup program's date
    if (widget.isPlayingCatchup && widget.currentCatchupProgram != null) {
      _selectedDate = widget.currentCatchupProgram!.start;
    } else {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void didUpdateWidget(InteractiveEpgWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel.id != widget.channel.id) {
      _hasInitialScrolled = false;
    }
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    _programScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 使用 GestureDetector 拦截点击事件，防止穿透到下层播放器
    // 宽度自适应：贴合最长节目名占用，最多铺满屏宽
    final panelWidth = _computePanelWidth(context);
    return GestureDetector(
        onTap: () {}, // 吞掉点击事件
        child: Container(
          width: panelWidth,
          decoration: const BoxDecoration(
            // 透明度对齐播放器左侧分类面板：90%→60%→透明渐变
            // 位于屏幕右侧，渐变方向与分类面板（左→透明）镜像，向中间淡出
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                Color(0xE6000000),
                Color(0x99000000),
                Colors.transparent,
              ],
              stops: [0.0, 0.7, 1.0],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  widget.channel.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Back to Live button (only if playing catchup)
              if (widget.isPlayingCatchup)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: ElevatedButton.icon(
                    onPressed: widget.onBackToLive,
                    icon: const Icon(Icons.live_tv),
                    label: const Text('回到直播 (Back to Live)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

              // 主区域：左竖排日期列 + 右节目列表
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 竖排日期选择器（窄列，避免宽度过大）
                    Container(
                      width: 66,
                      color: Colors.black.withOpacity(0.2),
                      child: Consumer<EpgProvider>(
                        builder: (context, epgProvider, child) {
                          final dates = epgProvider.getAvailableDates(
                            widget.channel.epgId ?? widget.channel.name,
                            widget.channel.name,
                          );

                          // 首次加载且非回放态时，校正初始选中日期：
                          // 若今天不在可用窗口内，自动落到最新可用一天，避免空白。
                          if (!_autoAdjustedDate && !widget.isPlayingCatchup) {
                            _autoAdjustedDate = true;
                            final today = DateTime.now();
                            final hasToday =
                                dates.any((d) => _isSameDay(d, today));
                            if (!hasToday && dates.isNotEmpty) {
                              final target = dates.last;
                              WidgetsBinding.instance.addPostFrameCallback((
                                  _) {
                                if (mounted) {
                                  setState(() => _selectedDate = target);
                                }
                              });
                            }
                          }

                          return ListView.builder(
                            controller: _dateScrollController,
                            scrollDirection: Axis.vertical,
                            itemExtent: 56,
                            itemCount: dates.length,
                            itemBuilder: (context, index) {
                              final date = dates[index];
                              final isSelected =
                                  _isSameDay(date, _selectedDate);
                              final isToday =
                                  _isSameDay(date, DateTime.now());

                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedDate = date;
                                  });
                                },
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : Colors.transparent,
                                        width: 3,
                                      ),
                                    ),
                                    color: isSelected
                                        ? AppTheme.primaryColor.withOpacity(
                                            0.2)
                                        : Colors.transparent,
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        isToday
                                            ? '今天'
                                            : DateFormat('MM-dd')
                                                .format(date),
                                        style: TextStyle(
                                          color: isSelected
                                              ? AppTheme.primaryColor
                                              : Colors.white70,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        _getWeekday(date),
                                        style: TextStyle(
                                          color: isSelected
                                              ? AppTheme.primaryColor
                                              : Colors.white54,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const VerticalDivider(
                        width: 1, color: Colors.white24),

                    // Program List
                    Expanded(
                      child: Consumer<EpgProvider>(
                  builder: (context, epgProvider, child) {
                    final programs = epgProvider.getProgramsForDate(
                      widget.channel.epgId ??
                          widget.channel.name, // Try epgId first, then name
                      widget.channel.name,
                      _selectedDate,
                    );

                    // 同步节目项 keys，数量变化时重建（用于高度自适应定位）
                    if (_itemKeys.length != programs.length) {
                      _itemKeys
                        ..clear()
                        ..addAll(
                            List.generate(programs.length, (_) => GlobalKey()));
                    }

                    if (programs.isEmpty) {
                      return const Center(
                        child: Text(
                          '暂无节目单',
                          style: TextStyle(color: Colors.white54),
                        ),
                      );
                    }

                    // 自动定位到当前节目（改用 ensureVisible，高度自适应后 index*高度估算失效）
                    if (!_hasInitialScrolled) {
                      _hasInitialScrolled = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        int targetIndex = -1;

                        if (widget.isPlayingCatchup &&
                            widget.currentCatchupProgram != null) {
                          // 定位到当前回放节目
                          targetIndex = programs.indexWhere((p) =>
                              p.start == widget.currentCatchupProgram!.start &&
                              p.title == widget.currentCatchupProgram!.title);
                        } else {
                          // 定位到当前直播节目
                          final now = DateTime.now();
                          targetIndex = programs.indexWhere((p) =>
                              now.isAfter(p.start) && now.isBefore(p.end));

                          // 如果找不到直播节目（可能时间不对），定位到最近的一个过去节目
                          if (targetIndex == -1) {
                            // 找最后一个结束时间在当前时间之前的节目
                            targetIndex = programs
                                .lastIndexWhere((p) => p.end.isBefore(now));
                          }
                        }

                        if (targetIndex >= 0 &&
                            _programScrollController.hasClients) {
                          // 高度自适应后 ListView.builder 懒加载，目标项若在视口外
                          // currentContext 为 null，直接 ensureVisible 会失效。
                          // 先按估算行高粗跳（不依赖 item 已构建），让目标进入构建
                          // 范围，再在下一帧精确居中。
                          const double estimateHeight = 76.0;
                          final maxScroll = _programScrollController
                              .position.maxScrollExtent;
                          final estimateOffset = (targetIndex * estimateHeight)
                              .clamp(0.0, maxScroll)
                              .toDouble();
                          _programScrollController.jumpTo(estimateOffset);

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            final ctx = _itemKeys[targetIndex].currentContext;
                            if (ctx != null) {
                              Scrollable.ensureVisible(
                                ctx,
                                alignment: 0.5,
                                duration: const Duration(milliseconds: 150),
                                curve: Curves.easeInOut,
                              );
                            }
                          });
                        }
                      });
                    }

                    return ListView.builder(
                      controller: _programScrollController,
                      itemCount: programs.length,
                      itemBuilder: (context, index) {
                        final program = programs[index];
                        final status = _getProgramStatus(program);
                        final isLive = status == ProgramStatus.live;
                        final isPast = status == ProgramStatus.past;

                        // 回放模式：当前正在回放的节目（时间在过去，需单独高亮标识）
                        final isCatchupCurrent =
                            widget.isPlayingCatchup &&
                            widget.currentCatchupProgram != null &&
                            program.start ==
                                widget.currentCatchupProgram!.start &&
                            program.title ==
                                widget.currentCatchupProgram!.title;

                        // Can play catchup if:
                        // 1. Program is in past
                        // 2. Channel supports catchup
                        // 3. Not too far in past (check catchupDays)
                        final canCatchup = isPast &&
                            widget.channel.hasCatchup &&
                            _isWithinCatchupRange(program);

                        return InkWell(
                          key: _itemKeys[index],
                          onTap: canCatchup
                              ? () => widget.onProgramSelected(program)
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            color: isLive
                                ? AppTheme.primaryColor.withOpacity(0.2)
                                : isCatchupCurrent
                                    ? Colors.greenAccent.withOpacity(0.15)
                                    : null,
                            child: Row(
                              children: [
                                // Time
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('HH:mm').format(program.start),
                                      style: TextStyle(
                                        color: isLive
                                            ? AppTheme.primaryColor
                                            : isCatchupCurrent
                                                ? Colors.greenAccent
                                                : Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('HH:mm').format(program.end),
                                      style: TextStyle(
                                        color: isLive
                                            ? AppTheme.primaryColor
                                                .withOpacity(0.7)
                                            : isCatchupCurrent
                                                ? Colors.greenAccent
                                                    .withOpacity(0.7)
                                                : Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),

                                // Title & Status
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        program.title,
                                        style: TextStyle(
                                          color: isLive
                                              ? AppTheme.primaryColor
                                              : isCatchupCurrent
                                                  ? Colors.greenAccent
                                                  : Colors.white,
                                          fontSize: 15,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (program.description != null &&
                                          program.description!.isNotEmpty)
                                        Text(
                                          program.description!,
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),

                                // Status Indicator
                                if (isLive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '直播',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 10),
                                    ),
                                  )
                                else if (isCatchupCurrent)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '回放中',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 10),
                                    ),
                                  )
                                else if (canCatchup)
                                  const Icon(Icons.play_circle_outline,
                                      color: Colors.white70, size: 20)
                                else if (!isPast)
                                  const Text(
                                    '即将播放',
                                    style: TextStyle(
                                        color: Colors.white30, fontSize: 10),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ));
  }

  /// 计算面板自适应宽度：贴合当前选中日节目名最长文本的占用，最多铺满屏宽。
  /// 节目名短则收窄（不因偏宽面板产生大量空白），超出屏宽则截到屏宽（长名省略）。
  double _computePanelWidth(BuildContext context) {
    final epgProvider = context.watch<EpgProvider>();
    final programs = epgProvider.getProgramsForDate(
      widget.channel.epgId ?? widget.channel.name,
      widget.channel.name,
      _selectedDate,
    );

    const double minPanelWidth = 380.0;
    final screenWidth = MediaQuery.of(context).size.width;

    if (programs.isEmpty) {
      return screenWidth < minPanelWidth ? screenWidth : minPanelWidth;
    }

    // 测量当前列表中最长的节目名宽度（单行，与列表项标题字体一致）
    double maxTitleWidth = 0;
    for (final p in programs) {
      final painter = TextPainter(
        text: TextSpan(
            text: p.title, style: const TextStyle(fontSize: 15)),
        maxLines: 1,
        textDirection: ui.TextDirection.ltr,
      )..layout();
      if (painter.width > maxTitleWidth) maxTitleWidth = painter.width;
    }

    // 左日期列66 + 分隔1 + 时间列 + 状态指示 + 间距与左右padding 的固定占用
    final neededWidth = maxTitleWidth + 66 + 1 + 60 + 32 + 30;
    return neededWidth.clamp(minPanelWidth, screenWidth).toDouble();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getWeekday(DateTime date) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[date.weekday - 1];
  }

  ProgramStatus _getProgramStatus(EpgProgram program) {
    final now = DateTime.now();
    if (now.isAfter(program.start) && now.isBefore(program.end)) {
      return ProgramStatus.live;
    } else if (now.isAfter(program.end)) {
      return ProgramStatus.past;
    } else {
      return ProgramStatus.future;
    }
  }

  bool _isWithinCatchupRange(EpgProgram program) {
    if (widget.channel.catchupDays == null) {
      return true; // Default to true if not specified? Or false?
    }
    // If catchupDays is set, check if program start is within days.
    // Assuming catchupDays means "last N days".
    final diff = DateTime.now().difference(program.start).inDays;
    return diff <= widget.channel.catchupDays!;
  }
}

enum ProgramStatus {
  past,
  live,
  future,
}
