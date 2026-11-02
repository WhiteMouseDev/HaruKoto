import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/services/haptic_service.dart';
import '../../data/models/dashboard_model.dart';

class WeeklyChart extends StatefulWidget {
  final List<WeeklyStatEntry> weeklyStats;
  final int dailyGoal;

  const WeeklyChart(
      {super.key, required this.weeklyStats, required this.dailyGoal});

  @override
  State<WeeklyChart> createState() => _WeeklyChartState();
}

class _WeeklyChartState extends State<WeeklyChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  int _wordCount(WeeklyStatEntry entry) =>
      entry.vocabularyAnsweredCount ?? entry.wordsStudied;

  String _dayOfWeek(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return _dayLabels[date.weekday - 1];
    } catch (_) {
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final totalWords =
        widget.weeklyStats.fold<int>(0, (a, e) => a + _wordCount(e));
    final totalXp = widget.weeklyStats.fold<int>(0, (a, e) => a + e.xpEarned);
    final hasActivity = widget.weeklyStats.any(
      (entry) =>
          entry.hasStudied || _wordCount(entry) > 0 || entry.xpEarned > 0,
    );
    final usesCompletionFallback = widget.weeklyStats
        .any((entry) => entry.vocabularyAnsweredCount == null);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              '주간 학습',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),

            // Chart area
            SizedBox(
              height: 120,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final barCount = widget.weeklyStats.length.clamp(0, 7);
                  if (barCount == 0 || !hasActivity) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.barChart3,
                            size: 32,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '이번 주 학습 기록이 아직 없어요',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            usesCompletionFallback
                                ? '학습을 마치면 완료 기준 기록이 표시돼요'
                                : '오늘 단어 1개만 학습해도 그래프가 채워져요',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.35),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Bars and target share a linear scale. Keep the upper 20px
                  // for goal checks, without inflating small or zero counts.
                  const barAreaHeight = 100.0;
                  final maxWords =
                      widget.weeklyStats.map(_wordCount).fold(0, math.max);
                  final scaleMax =
                      math.max(1, math.max(widget.dailyGoal, maxWords));
                  final goalLineY =
                      120 - widget.dailyGoal / scaleMax * barAreaHeight;

                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final animValue = CurvedAnimation(
                        parent: _controller,
                        curve: Curves.easeOutCubic,
                      ).value;

                      return Stack(
                        children: [
                          // Goal dashed line
                          if (widget.dailyGoal > 0)
                            Positioned(
                              key: const ValueKey('weekly-goal-line'),
                              top: goalLineY,
                              left: 0,
                              right: 64,
                              child: CustomPaint(
                                size: const Size(double.infinity, 1),
                                painter: _DashedLinePainter(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.15),
                                ),
                              ),
                            ),
                          if (widget.dailyGoal > 0)
                            Positioned(
                              top: goalLineY - 7,
                              right: 0,
                              child: Text(
                                '목표 ${widget.dailyGoal}개',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                            ),

                          // Bars
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(barCount, (i) {
                              final entry = widget.weeklyStats[i];
                              final value = _wordCount(entry);
                              final metGoal = widget.dailyGoal > 0 &&
                                  value >= widget.dailyGoal;
                              final animatedHeight = math.max(0, value) /
                                  scaleMax *
                                  barAreaHeight *
                                  animValue;

                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: i == 0 ? 0 : 4,
                                    right: i == barCount - 1 ? 0 : 4,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (metGoal && animValue > 0.9)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 2),
                                          child: Icon(
                                            LucideIcons.check,
                                            size: 12,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      Container(
                                        key: ValueKey(
                                            'weekly-word-bar-${entry.date}'),
                                        height: animatedHeight,
                                        decoration: BoxDecoration(
                                          color: metGoal
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.primary
                                                  .withValues(alpha: 0.5),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(6),
                                            topRight: Radius.circular(6),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Day labels
            Row(
              children: List.generate(
                widget.weeklyStats.length.clamp(0, 7),
                (i) => Expanded(
                  child: Center(
                    child: Semantics(
                      label: '${widget.weeklyStats[i].date}, '
                          '${widget.weeklyStats[i].hasStudied ? '학습 기록 있음' : '학습 기록 없음'}, '
                          '단어 ${_wordCount(widget.weeklyStats[i])}개'
                          '${widget.weeklyStats[i].vocabularyAnsweredCount == null ? ', 완료 기준' : ''}',
                      excludeSemantics: true,
                      child: Column(
                        children: [
                          Text(
                            _dayOfWeek(widget.weeklyStats[i].date),
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 4,
                            child: widget.weeklyStats[i].hasStudied
                                ? Container(
                                    key: ValueKey(
                                        'weekly-activity-${widget.weeklyStats[i].date}'),
                                    width: 4,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                usesCompletionFallback
                    ? '완료 기준 단어 수 포함 · 점은 학습한 날'
                    : '일별 저장 단어 합계 · 점은 학습한 날',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Summary
            Center(
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  children: [
                    const TextSpan(text: '단어 '),
                    TextSpan(
                      text: '$totalWords',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const TextSpan(text: '개 · XP '),
                    TextSpan(
                      text: '$totalXp',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Stats detail link
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  HapticService().selection();
                  context.push('/stats');
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    '학습 통계 자세히 보기 →',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    var startX = 0.0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(math.min(startX + dashWidth, size.width), 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      color != oldDelegate.color;
}
