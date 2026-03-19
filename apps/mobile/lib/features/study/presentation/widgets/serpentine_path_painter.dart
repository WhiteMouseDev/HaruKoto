import 'package:flutter/material.dart';

import '../../data/models/stage_model.dart';

class SerpentinePathPainter extends CustomPainter {
  final List<Offset> positions;
  final List<StageModel> stages;
  final Color completedColor;
  final Color activeColor;
  final Color lockedColor;

  SerpentinePathPainter({
    required this.positions,
    required this.stages,
    required this.completedColor,
    required this.activeColor,
    required this.lockedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < positions.length - 1; i++) {
      final start = positions[i];
      final end = positions[i + 1];
      final midY = (start.dy + end.dy) / 2;

      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(start.dx, midY, end.dx, midY, end.dx, end.dy);

      final isNextLocked = stages[i + 1].isLocked;
      final isCurrentCompleted = stages[i].isCompleted;

      if (isNextLocked) {
        _drawDashedPath(canvas, path, lockedColor, 2.0);
      } else {
        final color = isCurrentCompleted ? completedColor : activeColor;
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  void _drawDashedPath(
      Canvas canvas, Path path, Color color, double width) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + 6).clamp(0.0, metric.length);
        final extracted = metric.extractPath(distance, end);
        canvas.drawPath(extracted, paint);
        distance += 12; // 6px dash + 6px gap
      }
    }
  }

  @override
  bool shouldRepaint(SerpentinePathPainter oldDelegate) =>
      oldDelegate.positions != positions || oldDelegate.stages != stages;
}
