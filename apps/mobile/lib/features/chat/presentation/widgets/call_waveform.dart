import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/character_assets.dart';
import '../../../../core/constants/colors.dart';

class CallWaveformWidget extends StatefulWidget {
  final String mode; // 'idle' | 'speaking' | 'listening'
  final String? avatarUrl;
  final String? characterName;

  const CallWaveformWidget({
    super.key,
    this.mode = 'idle',
    this.avatarUrl,
    this.characterName,
  });

  @override
  State<CallWaveformWidget> createState() => _CallWaveformWidgetState();
}

class _CallWaveformWidgetState extends State<CallWaveformWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildAvatar() {
    final localPath = CharacterAssets.pathFor(widget.characterName);
    if (localPath != null) {
      return CircleAvatar(
        radius: 64,
        backgroundColor: AppColors.callSurface,
        backgroundImage: AssetImage(localPath),
      );
    }
    if (widget.avatarUrl != null) {
      return CircleAvatar(
        radius: 64,
        backgroundColor: AppColors.callSurface,
        backgroundImage: CachedNetworkImageProvider(widget.avatarUrl!),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }
    return const CircleAvatar(
      radius: 64,
      backgroundColor: AppColors.callSurface,
      child: Text('\u{1F98A}', style: TextStyle(fontSize: 48)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _WaveformPainter(
              progress: _controller.value,
              mode: widget.mode,
            ),
            child: child,
          );
        },
        child: Center(
          child: Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.callAccent.withValues(alpha: 0.25),
                  blurRadius: 24,
                ),
              ],
            ),
            child: _buildAvatar(),
          ),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  final String mode;

  static const _ringCount = 4;
  static const _baseScale = [1.3, 1.55, 1.8, 2.05];
  static const _baseOpacity = [0.25, 0.18, 0.12, 0.06];

  _WaveformPainter({required this.progress, required this.mode});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const baseRadius = 64.0; // half of avatar size

    for (var i = 0; i < _ringCount; i++) {
      double scale;
      double opacity;

      if (mode == 'speaking') {
        final wave = sin((progress + i * 0.3) * 2 * pi);
        scale = _baseScale[i] + wave * 0.08;
        opacity = _baseOpacity[i] + wave * 0.04;
      } else if (mode == 'listening') {
        scale = _baseScale[i];
        opacity = _baseOpacity[i];
      } else {
        // idle
        scale = _baseScale[i];
        opacity = _baseOpacity[i] * 0.5;
      }

      final paint = Paint()
        ..color =
            AppColors.callAccentLight.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      canvas.drawCircle(center, baseRadius * scale, paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress || old.mode != mode;
}
