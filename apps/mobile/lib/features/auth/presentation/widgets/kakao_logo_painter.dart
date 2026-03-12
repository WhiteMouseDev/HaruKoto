import 'package:flutter/material.dart';

Widget kakaoIcon() {
  return SizedBox(
    width: 20,
    height: 20,
    child: CustomPaint(painter: KakaoLogoPainter()),
  );
}

class KakaoLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 24;
    final path = Path()
      ..moveTo(12 * s, 3 * s)
      ..cubicTo(6.48 * s, 3 * s, 2 * s, 6.48 * s, 2 * s,
          10.5 * s)
      ..cubicTo(2 * s, 13.13 * s, 3.74 * s, 15.44 * s,
          6.35 * s, 16.74 * s)
      ..cubicTo(6.22 * s, 17.22 * s, 5.51 * s, 19.81 * s,
          5.48 * s, 20.01 * s)
      ..cubicTo(5.48 * s, 20.01 * s, 5.46 * s, 20.09 * s,
          5.52 * s, 20.12 * s)
      ..cubicTo(5.58 * s, 20.15 * s, 5.65 * s, 20.13 * s,
          5.65 * s, 20.13 * s)
      ..cubicTo(5.82 * s, 20.11 * s, 8.8 * s, 18.05 * s,
          9.29 * s, 17.7 * s)
      ..cubicTo(10.17 * s, 17.83 * s, 11.08 * s, 17.9 * s,
          12 * s, 17.9 * s)
      ..cubicTo(17.52 * s, 17.9 * s, 22 * s, 14.42 * s,
          22 * s, 10.4 * s)
      ..cubicTo(22 * s, 6.48 * s, 17.52 * s, 3 * s,
          12 * s, 3 * s)
      ..close();
    canvas.drawPath(
        path, Paint()..color = const Color(0xFF191919));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      false;
}
