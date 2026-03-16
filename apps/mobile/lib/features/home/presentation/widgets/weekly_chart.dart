import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../../data/models/dashboard_model.dart';

class WeeklyChart extends StatelessWidget {
  final List<WeeklyStatEntry> weeklyStats;
  final int dailyGoal;

  const WeeklyChart(
      {super.key, required this.weeklyStats, required this.dailyGoal});

  static const _dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  String _dayOfWeek(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return _dayLabels[date.weekday - 1];
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final totalWords = weeklyStats.fold<int>(0, (a, e) => a + e.wordsStudied);
    final totalXp = weeklyStats.fold<int>(0, (a, e) => a + e.xpEarned);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.lightBorder),
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
                  final barCount = weeklyStats.length.clamp(0, 7);
                  if (barCount == 0) {
                    return const Center(child: Text('데이터 없음'));
                  }

                  const goalLineY = 120.0 * 0.3;

                  return Stack(
                    children: [
                      // Goal dashed line
                      Positioned(
                        top: goalLineY,
                        left: 0,
                        right: 0,
                        child: Row(
                          children: [
                            Expanded(
                              child: CustomPaint(
                                size: const Size(double.infinity, 1),
                                painter: _DashedLinePainter(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.15),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '목표',
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Bars
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(barCount, (i) {
                          final value = weeklyStats[i].wordsStudied;
                          final metGoal = value >= dailyGoal && value > 0;

                          double barHeight;
                          if (value <= 0) {
                            barHeight = 3;
                          } else {
                            barHeight =
                                math.sqrt(value / dailyGoal) * 0.7 * 120;
                            barHeight = barHeight.clamp(16, 120);
                          }

                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: i == 0 ? 0 : 4,
                                right: i == barCount - 1 ? 0 : 4,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (metGoal)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Icon(
                                        Icons.check,
                                        size: 12,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  Container(
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      color: value <= 0
                                          ? theme.colorScheme.onSurface
                                              .withValues(alpha: 0.15)
                                          : metGoal
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
              ),
            ),
            const SizedBox(height: 8),

            // Day labels
            Row(
              children: List.generate(
                weeklyStats.length.clamp(0, 7),
                (i) => Expanded(
                  child: Center(
                    child: Text(
                      _dayOfWeek(weeklyStats[i].date),
                      style: TextStyle(
                        fontSize: 10,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
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
              child: GestureDetector(
                onTap: () => context.push('/stats'),
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
