import 'package:flutter/material.dart';

/// An original illustration for each of the three scenes in the pilot.
class ConversationJourneyScene extends StatelessWidget {
  const ConversationJourneyScene({
    super.key,
    required this.episodeNumber,
    this.height = 112,
  });

  final int episodeNumber;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExcludeSemantics(
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: ClipRect(
          child: CustomPaint(
            painter: _JourneyScenePainter(
              episodeNumber: episodeNumber,
              darkSurface: theme.brightness == Brightness.dark
                  ? theme.colorScheme.surface
                  : null,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _JourneyScenePainter extends CustomPainter {
  const _JourneyScenePainter({
    required this.episodeNumber,
    required this.darkSurface,
  });

  final int episodeNumber;
  final Color? darkSurface;

  static const _cream = Color(0xFFFFF6EB);
  static const _sky = Color(0xFFC4DCD7);
  static const _rose = Color(0xFFD35A78);
  static const _green = Color(0xFF385655);
  static const _wood = Color(0xFF775048);

  Color _shade(Color color) =>
      darkSurface == null ? color : Color.lerp(color, darkSurface, 0.36)!;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()..isAntiAlias = true;
    final base = switch (episodeNumber) {
      1 => _sky,
      2 => const Color(0xFFE6CCAE),
      _ => const Color(0xFFF4DAE1),
    };
    canvas.drawRect(Offset.zero & size, paint..color = _shade(base));

    // Preserve illustration proportions at both narrow and tablet widths.
    final scale = size.height / 112;
    canvas
      ..save()
      ..translate((size.width - 320 * scale) / 2, 0)
      ..scale(scale);
    switch (episodeNumber) {
      case 1:
        _train(canvas, paint);
      case 2:
        _hotel(canvas, paint);
      default:
        _cafe(canvas, paint);
    }
    canvas.restore();
  }

  void _train(Canvas canvas, Paint paint) {
    canvas.drawCircle(const Offset(237, 28), 17, paint..color = _shade(_cream));
    _block(canvas, paint, -440, 91, 1200, 21, _wood);
    _block(canvas, paint, -440, 91, 1200, 4, const Color(0xFFF4CD83));
    _block(canvas, paint, 39, 45, 241, 46, _cream, radius: 17);
    _block(canvas, paint, 39, 79, 241, 6, _green, radius: 3);
    for (var i = 0; i < 5; i++) {
      _block(canvas, paint, 56 + i * 40.0, 54, 29, 15, _green, radius: 4);
    }
    _block(canvas, paint, 250, 69, 15, 4, const Color(0xFFF4CD83), radius: 2);
  }

  void _hotel(Canvas canvas, Paint paint) {
    const arch = Radius.circular(62);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        const Rect.fromLTWH(60, 6, 128, 106),
        topLeft: arch,
        topRight: arch,
      ),
      paint..color = _shade(_cream),
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        const Rect.fromLTWH(65, 11, 118, 101),
        topLeft: arch,
        topRight: arch,
      ),
      paint..color = _shade(_sky),
    );
    canvas.drawCircle(const Offset(103, 46), 13,
        paint..color = _shade(const Color(0xFFFFDA8A)));
    final mountains = Path()
      ..moveTo(65, 88)
      ..lineTo(93, 65)
      ..lineTo(118, 86)
      ..lineTo(145, 62)
      ..lineTo(183, 85)
      ..lineTo(183, 111)
      ..lineTo(65, 111)
      ..close();
    canvas.drawPath(mountains, paint..color = _shade(const Color(0xFF98B9B0)));
    _block(canvas, paint, 122, 11, 2, 101, _cream);
    _person(canvas, paint, 235);
    _block(canvas, paint, 159, 84, 610, 28, _wood, radius: 6);
    _block(canvas, paint, 159, 84, 610, 5, _cream, radius: 3);
    _block(canvas, paint, 55, 75, 13, 18, _wood, radius: 3);
    _block(canvas, paint, 57, 78, 9, 13, _sky, radius: 2);
    _block(canvas, paint, 49, 85, 25, 27, _rose, radius: 5);
    _block(canvas, paint, 55, 89, 2, 18, _cream, radius: 1);
  }

  void _cafe(Canvas canvas, Paint paint) {
    _block(canvas, paint, 58, 2, 207, 80, _cream, radius: 8);
    _block(canvas, paint, 68, 18, 186, 64, const Color(0xFFD7C6B4));
    _person(canvas, paint, 222);
    for (var i = 0; i < 8; i++) {
      _block(canvas, paint, 52 + 27.0 * i, 0, 27, 21, i.isEven ? _rose : _cream,
          radius: 4);
    }
    _block(canvas, paint, -440, 88, 1200, 24, _wood);
    _block(canvas, paint, -440, 88, 1200, 5, _cream);
    final cup = Path()
      ..moveTo(96, 57)
      ..lineTo(130, 57)
      ..lineTo(124, 88)
      ..lineTo(102, 88)
      ..close();
    canvas.drawPath(cup, paint..color = _shade(_cream));
    _block(canvas, paint, 97, 66, 32, 10, _rose, radius: 2);
    _block(canvas, paint, 94, 54, 38, 6, _green, radius: 3);
  }

  void _person(Canvas canvas, Paint paint, double x) {
    _block(canvas, paint, x - 26, 47, 52, 48, _green, radius: 20);
    canvas.drawCircle(
        Offset(x, 43), 17, paint..color = _shade(const Color(0xFF5B3B35)));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, 47), width: 31, height: 26),
      paint..color = _shade(const Color(0xFFE7AB8E)),
    );
    canvas.drawCircle(Offset(x - 5, 46), 1.1, paint..color = _shade(_wood));
    canvas.drawCircle(Offset(x + 5, 46), 1.1, paint);
    _block(canvas, paint, x + 6, 70, 9, 3, _cream, radius: 1.5);
  }

  void _block(
    Canvas canvas,
    Paint paint,
    double x,
    double y,
    double width,
    double height,
    Color color, {
    double radius = 0,
  }) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, width, height), Radius.circular(radius)),
      paint..color = _shade(color),
    );
  }

  @override
  bool shouldRepaint(covariant _JourneyScenePainter oldDelegate) =>
      episodeNumber != oldDelegate.episodeNumber ||
      darkSurface != oldDelegate.darkSurface;
}
