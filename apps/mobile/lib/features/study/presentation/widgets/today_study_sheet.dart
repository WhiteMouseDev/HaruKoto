import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../data/models/smart_preview_model.dart';
import '../../providers/study_provider.dart';
import '../../../home/providers/home_provider.dart';
import '../quiz_page.dart';

/// Bottom sheet for "오늘의 학습" — shows smart quiz preview,
/// distribution breakdown, goal setting, and start button.
class TodayStudySheet extends ConsumerStatefulWidget {
  final SmartPreviewModel data;
  final String jlptLevel;

  const TodayStudySheet({
    super.key,
    required this.data,
    required this.jlptLevel,
  });

  @override
  ConsumerState<TodayStudySheet> createState() => _TodayStudySheetState();
}

class _TodayStudySheetState extends ConsumerState<TodayStudySheet> {
  bool _isGoalLoading = false;

  Future<void> _updateGoal(int goal) async {
    if (_isGoalLoading) return;
    setState(() => _isGoalLoading = true);
    try {
      await ref.read(homeRepositoryProvider).updateDailyGoal(goal);
      ref.invalidate(dashboardProvider);
      ref.invalidate(profileProvider);
      ref.invalidate(
        smartPreviewProvider(
            (category: 'VOCABULARY', jlptLevel: widget.jlptLevel)),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('하루 목표가 $goal개로 변경되었습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('목표 변경에 실패했습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoalLoading = false);
    }
  }

  void _showGoalPicker() {
    final goals = [5, 10, 15, 20, 30];
    final currentGoal = widget.data.dailyGoal;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHandle(Theme.of(ctx)),
                const SizedBox(height: 16),
                Text(
                  '하루 목표 설정',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                ...goals.map((g) {
                  final isActive = g == currentGoal;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    selected: isActive,
                    selectedTileColor: Theme.of(ctx)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.08),
                    title: Text(
                      '$g개',
                      style: TextStyle(
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive
                            ? Theme.of(ctx).colorScheme.primary
                            : Theme.of(ctx).colorScheme.onSurface,
                      ),
                    ),
                    trailing: _isGoalLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : isActive
                            ? Icon(LucideIcons.check,
                                color: Theme.of(ctx).colorScheme.primary,
                                size: 20)
                            : null,
                    enabled: !_isGoalLoading,
                    onTap: () {
                      Navigator.pop(ctx);
                      _updateGoal(g);
                    },
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = widget.data;
    final dist = data.sessionDistribution;
    final progress = data.overallProgress;
    final progressPct =
        progress.total > 0 ? (progress.studied / progress.total) : 0.0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(theme),
            const SizedBox(height: 20),

            // Title
            Text(
              '오늘의 학습',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Progress ring + stats
            Row(
              children: [
                // Circular progress
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CustomPaint(
                    painter: _CircularProgressPainter(
                      progress: progressPct.clamp(0.0, 1.0),
                      trackColor:
                          theme.colorScheme.primary.withValues(alpha: 0.10),
                      progressColor: AppColors.primaryStrong,
                      strokeWidth: 6,
                    ),
                    child: Center(
                      child: Text(
                        '${progress.percentage}%',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.jlptLevel} 단어',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${progress.studied} / ${progress.total}개 학습',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Goal row
                      GestureDetector(
                        onTap: _showGoalPicker,
                        child: Row(
                          children: [
                            Text(
                              '하루 목표 ${data.dailyGoal}개',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              LucideIcons.pencil,
                              size: 12,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Distribution breakdown
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _DistItem(
                    label: '새로운 단어',
                    count: dist.newCount,
                    color: theme.colorScheme.primary,
                  ),
                  _divider(theme),
                  _DistItem(
                    label: '복습할 단어',
                    count: dist.review,
                    color: const Color(0xFF10B981),
                  ),
                  _divider(theme),
                  _DistItem(
                    label: '재도전 단어',
                    count: dist.retry,
                    color: theme.colorScheme.error,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Start button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: dist.total > 0
                    ? () {
                        Navigator.pop(context);
                        Navigator.of(context, rootNavigator: true).push(
                          quizRoute(QuizPage(
                            quizType: 'VOCABULARY',
                            jlptLevel: widget.jlptLevel,
                            count: dist.total,
                            mode: 'smart',
                          )),
                        );
                      }
                    : null,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  dist.total > 0 ? '학습 시작 (${dist.total}문제)' : '학습할 단어가 없습니다',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle(ThemeData theme) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _divider(ThemeData theme) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: theme.colorScheme.outline.withValues(alpha: 0.15),
    );
  }
}

class _DistItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _DistItem({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CircularProgressPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.progressColor != progressColor;
}
