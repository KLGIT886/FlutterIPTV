import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../epg/providers/epg_provider.dart';
import '../../../core/services/epg_service.dart';

class EpgScreen extends StatefulWidget {
  final String? channelId;
  final String? channelName;

  const EpgScreen({
    super.key,
    this.channelId,
    this.channelName,
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
            _buildTimeRangeHeader(),
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

                  final programs = epgProvider.getProgramsInTimeRange(
                    widget.channelId,
                    widget.channelName,
                    timeZoneOffset,
                    daysBefore: daysBefore,
                    daysAfter: daysAfter,
                  );

                  if (programs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today, size: 64, color: AppTheme.getTextMuted(context)),
                          const SizedBox(height: 16),
                          Text(
                            '该时间段内无节目',
                            style: TextStyle(
                              color: AppTheme.getTextSecondary(context),
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '时间范围：前${daysBefore}天到后${daysAfter}天',
                            style: TextStyle(
                              color: AppTheme.getTextMuted(context),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: programs.length,
                    itemBuilder: (context, index) {
                      final program = programs[index];
                      return _buildProgramCard(program);
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

  Widget _buildTimeRangeHeader() {
    final now = DateTime.now().add(Duration(hours: timeZoneOffset));
    final startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysBefore));
    final endDate = DateTime(now.year, now.month, now.day).add(Duration(days: daysAfter + 1));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.getSurfaceColor(context).withOpacity(0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '时间范围: ${_formatDate(startDate)} 至 ${_formatDate(endDate.subtract(const Duration(days: 1)))}',
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 14,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.getPrimaryColor(context).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '共${daysBefore + daysAfter + 1}天',
              style: TextStyle(
                color: AppTheme.getPrimaryColor(context),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramCard(EpgProgram program) {
    final localStart = program.startInTimeZone(timeZoneOffset);
    final localEnd = program.endInTimeZone(timeZoneOffset);
    final duration = localEnd.difference(localStart);
    final isNow = program.isNowInTimeZone(timeZoneOffset);
    final isNext = program.isNextInTimeZone(timeZoneOffset);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNow
              ? AppTheme.successColor
              : isNext
                  ? AppTheme.getPrimaryColor(context).withOpacity(0.5)
                  : AppTheme.getGlassBorderColor(context),
          width: isNow ? 2 : 1,
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
                if (isNow)
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
                else if (isNext)
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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
