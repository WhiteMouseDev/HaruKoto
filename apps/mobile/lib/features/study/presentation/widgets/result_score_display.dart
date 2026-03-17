import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';

class ResultScoreDisplay extends StatefulWidget {
  final int accuracy;
  final int correct;
  final int total;
  final int xpEarned;
  final int currentXp;
  final int xpForNext;

  const ResultScoreDisplay({
    super.key,
    required this.accuracy,
    required this.correct,
    required this.total,
    required this.xpEarned,
    required this.currentXp,
    required this.xpForNext,
  });

  @override
  State<ResultScoreDisplay> createState() => _ResultScoreDisplayState();
}

class _ResultScoreDisplayState extends State<ResultScoreDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final wrongCount = widget.total - widget.correct;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Accuracy circle
          SizedBox(
            width: 112,
            height: 112,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _AccuracyCirclePainter(
                    progress: _controller.value * widget.accuracy / 100,
                    bgColor: theme.colorScheme.surfaceContainerHigh,
                    fgColor: AppColors.primaryStrong,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(_controller.value * widget.accuracy).round()}%',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '정답률',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Stats row
          Row(
            children: [
              _StatTile(
                icon: LucideIcons.target,
                iconColor: AppColors.primaryStrong,
                value: '${widget.correct}/${widget.total}',
                label: '정답',
                theme: theme,
              ),
              const SizedBox(width: 12),
              _StatTile(
                icon: LucideIcons.zap,
                iconColor: AppColors.hkYellow(brightness),
                value: '+${widget.xpEarned}',
                label: 'XP',
                theme: theme,
                xpProgress: widget.xpForNext > 0
                    ? widget.currentXp / widget.xpForNext
                    : 0,
                xpRemaining: widget.xpForNext - widget.currentXp,
              ),
              const SizedBox(width: 12),
              _StatTile(
                icon: LucideIcons.xCircle,
                iconColor: AppColors.error(brightness),
                value: '$wrongCount',
                label: '오답',
                theme: theme,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final ThemeData theme;
  final double? xpProgress;
  final int? xpRemaining;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.theme,
    this.xpProgress,
    this.xpRemaining,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
            if (xpProgress != null) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: xpProgress!.clamp(0, 1),
                  minHeight: 6,
                  backgroundColor: AppColors.overlay(0.1),
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '다음 레벨까지 ${xpRemaining ?? 0} XP',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 9,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccuracyCirclePainter extends CustomPainter {
  final double progress;
  final Color bgColor;
  final Color fgColor;

  _AccuracyCirclePainter({
    required this.progress,
    required this.bgColor,
    required this.fgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 8.0;

    // Background circle
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = bgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..color = fgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_AccuracyCirclePainter old) => old.progress != progress;
}
