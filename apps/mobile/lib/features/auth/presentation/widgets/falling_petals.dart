import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Cherry blossom petals with individual lifecycles.
/// Each petal fades in, sways gently, fades out, then respawns
/// at a new position — creating an endlessly organic feel.
class FallingPetals extends StatefulWidget {
  final int petalCount;
  final bool loop;

  const FallingPetals({
    super.key,
    this.petalCount = 14,
    this.loop = false,
    Duration? duration, // kept for API compat but unused now
  });

  @override
  State<FallingPetals> createState() => _FallingPetalsState();
}

class _FallingPetalsState extends State<FallingPetals>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Petal> _petals;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    // Ticker runs indefinitely; each petal tracks its own time
    _controller = AnimationController.unbounded(vsync: this);

    _petals = List.generate(widget.petalCount, (_) => _spawnPetal(initial: true));

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _controller.value = 0;
        _controller.animateTo(
          // Animate for a very long time; effectively infinite
          86400.0, // seconds worth of progress
          duration: const Duration(hours: 24),
          curve: Curves.linear,
        );
      }
    });
  }

  _Petal _spawnPetal({bool initial = false}) {
    // Lifespan: 4~8 seconds mapped to controller progress
    final lifespan = 4.0 + _random.nextDouble() * 4.0;
    // Fade in/out takes ~15% of lifespan each
    final fadeDuration = lifespan * 0.15;

    // If initial, stagger birth so petals don't all appear at once
    final birthTime = initial
        ? _random.nextDouble() * 3.0 // spread over first 3 seconds
        : _controller.value;

    return _Petal(
      x: 0.05 + _random.nextDouble() * 0.9,
      y: 0.05 + _random.nextDouble() * 0.9,
      size: 7 + _random.nextDouble() * 11,
      swayAmountX: 0.02 + _random.nextDouble() * 0.03,
      swayFreqX: 0.8 + _random.nextDouble() * 0.6,
      swayAmountY: 0.008 + _random.nextDouble() * 0.012,
      swayFreqY: 0.6 + _random.nextDouble() * 0.5,
      rotationSpeed: 0.4 + _random.nextDouble() * 0.6,
      flutterFreq: 0.8 + _random.nextDouble() * 1.2,
      maxOpacity: 0.14 + _random.nextDouble() * 0.18,
      phase: _random.nextDouble() * math.pi * 2,
      color: _random.nextBool()
          ? const Color(0xFFFFB7C5)
          : const Color(0xFFF6A5B3),
      birthTime: birthTime,
      lifespan: lifespan,
      fadeDuration: fadeDuration,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final now = _controller.value;

        // Respawn dead petals (only if looping)
        if (widget.loop) {
          for (int i = 0; i < _petals.length; i++) {
            final p = _petals[i];
            if (now > p.birthTime + p.lifespan) {
              _petals[i] = _spawnPetal();
            }
          }
        }

        return CustomPaint(
          painter: _PetalPainter(petals: _petals, now: now),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Petal {
  final double x;
  final double y;
  final double size;
  final double swayAmountX;
  final double swayFreqX;
  final double swayAmountY;
  final double swayFreqY;
  final double rotationSpeed;
  final double flutterFreq;
  final double maxOpacity;
  final double phase;
  final Color color;
  final double birthTime;
  final double lifespan;
  final double fadeDuration;

  const _Petal({
    required this.x,
    required this.y,
    required this.size,
    required this.swayAmountX,
    required this.swayFreqX,
    required this.swayAmountY,
    required this.swayFreqY,
    required this.rotationSpeed,
    required this.flutterFreq,
    required this.maxOpacity,
    required this.phase,
    required this.color,
    required this.birthTime,
    required this.lifespan,
    required this.fadeDuration,
  });
}

class _PetalPainter extends CustomPainter {
  final List<_Petal> petals;
  final double now;

  _PetalPainter({required this.petals, required this.now});

  @override
  void paint(Canvas canvas, Size size) {
    for (final petal in petals) {
      final age = now - petal.birthTime;
      if (age < 0 || age > petal.lifespan) continue;

      // Lifecycle opacity: fade in → full → fade out
      double opacity;
      if (age < petal.fadeDuration) {
        // Fade in
        opacity = (age / petal.fadeDuration) * petal.maxOpacity;
      } else if (age > petal.lifespan - petal.fadeDuration) {
        // Fade out
        final remaining = petal.lifespan - age;
        opacity = (remaining / petal.fadeDuration) * petal.maxOpacity;
      } else {
        opacity = petal.maxOpacity;
      }
      if (opacity <= 0.01) continue;

      // Time-based sway (continuous, not 0-1 bounded)
      final t = age;

      final swayX =
          math.sin(t * math.pi * 2 * petal.swayFreqX / petal.lifespan +
                  petal.phase) *
              petal.swayAmountX *
              size.width;
      final swayY =
          math.cos(t * math.pi * 2 * petal.swayFreqY / petal.lifespan +
                  petal.phase * 1.3) *
              petal.swayAmountY *
              size.height;

      final px = petal.x * size.width + swayX;
      final py = petal.y * size.height + swayY;

      final rotation = math.sin(
                  t * math.pi * 2 * petal.rotationSpeed / petal.lifespan +
                      petal.phase) *
              0.5 +
          petal.phase;

      final flutter = math.sin(
          t * math.pi * 2 * petal.flutterFreq / petal.lifespan +
              petal.phase * 2.1);
      final scaleX = 0.3 + 0.7 * flutter.abs();

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(rotation);
      canvas.scale(scaleX, 1.0);

      final paint = Paint()
        ..color = petal.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      final path = Path();
      final s = petal.size;

      path.moveTo(0, -s * 0.5);
      path.cubicTo(s * 0.5, -s * 0.35, s * 0.45, s * 0.15, 0, s * 0.5);
      path.cubicTo(-s * 0.45, s * 0.15, -s * 0.5, -s * 0.35, 0, -s * 0.5);

      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PetalPainter old) => true; // Ticker-driven, always repaint
}
