import 'package:flutter/material.dart';
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

  const InteractiveEpgWidget({
    Key? key,
    required this.channel,
    required this.onProgramSelected,
    required this.onBackToLive,
    this.isPlayingCatchup = false,
  }) : super(key: key);

  @override
  State<InteractiveEpgWidget> createState() => _InteractiveEpgWidgetState();
}

class _InteractiveEpgWidgetState extends State<InteractiveEpgWidget> {
  late DateTime _selectedDate;
  final ScrollController _dateScrollController = ScrollController();
  final ScrollController _programScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    _programScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 800,
      color: Colors.black.withOpacity(0.85),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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

          // Date Selector
          SizedBox(
            height: 60,
            child: ListView.builder(
              controller: _dateScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: 8, // -5 days, today, +2 days = 8 days
              itemBuilder: (context, index) {
                // Calculate date: index 0 is -5 days, index 5 is today
                final date = DateTime.now().add(Duration(days: index - 5));
                final isSelected = _isSameDay(date, _selectedDate);
                final isToday = _isSameDay(date, DateTime.now());

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                    });
                  },
                  child: Container(
                    width: 80,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      color: isSelected ? Colors.white10 : Colors.transparent,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isToday ? '今天' : DateFormat('MM-dd').format(date),
                          style: TextStyle(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : Colors.white70,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        Text(
                          _getWeekday(date),
                          style: TextStyle(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1, color: Colors.white24),

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

                if (programs.isEmpty) {
                  return const Center(
                    child: Text(
                      '暂无节目单',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _programScrollController,
                  itemCount: programs.length,
                  itemBuilder: (context, index) {
                    final program = programs[index];
                    final status = _getProgramStatus(program);
                    final isLive = status == ProgramStatus.live;
                    final isPast = status == ProgramStatus.past;

                    // Can play catchup if:
                    // 1. Program is in past
                    // 2. Channel supports catchup
                    // 3. Not too far in past (check catchupDays)
                    final canCatchup = isPast &&
                        widget.channel.hasCatchup &&
                        _isWithinCatchupRange(program);

                    return InkWell(
                      onTap: canCatchup
                          ? () => widget.onProgramSelected(program)
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        color: isLive
                            ? AppTheme.primaryColor.withOpacity(0.2)
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
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  DateFormat('HH:mm').format(program.end),
                                  style: TextStyle(
                                    color: isLive
                                        ? AppTheme.primaryColor.withOpacity(0.7)
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    program.title,
                                    style: TextStyle(
                                      color: isLive
                                          ? AppTheme.primaryColor
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
    );
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
    if (widget.channel.catchupDays == null)
      return true; // Default to true if not specified? Or false?
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
