import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/services/tts_service.dart';

class TtsPlayButton extends StatefulWidget {
  final String? vocabId;
  final String? text;
  final String? url;
  final double iconSize;

  const TtsPlayButton({
    super.key,
    this.vocabId,
    this.text,
    this.url,
    this.iconSize = 20,
  }) : assert(vocabId != null || text != null || url != null,
            'Either vocabId, text, or url must be provided');

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
      if (widget.url != null) {
        await tts.playUrl(widget.url!);
      } else if (widget.vocabId != null) {
        await tts.play(widget.vocabId!);
      } else {
        await tts.playText(widget.text!);
      }
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
      return Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: widget.iconSize,
          height: widget.iconSize,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          LucideIcons.volume2,
          size: widget.iconSize,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
