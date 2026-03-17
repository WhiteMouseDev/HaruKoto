import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/services/tts_service.dart';

class TtsPlayButton extends StatefulWidget {
  final String vocabId;
  final double iconSize;

  const TtsPlayButton({
    super.key,
    required this.vocabId,
    this.iconSize = 20,
  });

  @override
  State<TtsPlayButton> createState() => _TtsPlayButtonState();
}

class _TtsPlayButtonState extends State<TtsPlayButton> {
  bool _loading = false;

  Future<void> _onTap() async {
    if (_loading) return;

    final tts = TtsService();
    if (tts.isPlaying) {
      tts.stop();
      return;
    }

    setState(() => _loading = true);
    try {
      await tts.play(widget.vocabId);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return SizedBox(
        width: widget.iconSize,
        height: widget.iconSize,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _onTap,
      child: Icon(
        LucideIcons.volume2,
        size: widget.iconSize,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }
}
