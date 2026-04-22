import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../data/models/smart_preview_model.dart';

class TodayStudyProgressSummary extends StatelessWidget {
  final OverallProgress progress;
  final String jlptLevel;
  final String category;
  final int currentGoal;
  final VoidCallback onGoalTap;

  const TodayStudyProgressSummary({
    super.key,
    required this.progress,
    required this.jlptLevel,
    required this.category,
    required this.currentGoal,
    required this.onGoalTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressPct =
        progress.total > 0 ? (progress.studied / progress.total) : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: CustomPaint(
            painter: _CircularProgressPainter(
              progress: progressPct.clamp(0.0, 1.0),
              trackColor: theme.colorScheme.primary.withValues(alpha: 0.10),
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$jlptLevel ${category == 'GRAMMAR' ? '문법' : '단어'}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${progress.studied} / ${progress.total}개 학습',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onGoalTap,
                child: Row(
                  children: [
                    Text(
                      '하루 목표 $currentGoal개',
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
